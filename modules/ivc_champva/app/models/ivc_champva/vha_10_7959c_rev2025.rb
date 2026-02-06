# frozen_string_literal: true

# 10-7959C Rev 2025 - Other Health Insurance Certification form.
#
# This form is used both with:
# 1. The 10-10d/10-7959c merged form experience (e.g., "10-10D-EXTENDED")
# 2. Standalone 10-7959C submissions when the rev2025 feature flag is enabled
#
# Both flows send data with an `applicants` array containing nested `health_insurance`
# and `medicare` arrays. The constructor handles all necessary transformations:
# - Extracts first applicant data and merges with form-level fields
# - Flattens health_insurance policies to `applicant_primary_*` / `applicant_secondary_*` fields

require 'vets/model'

module IvcChampva
  class VHA107959cRev2025
    STATS_KEY = 'api.ivc_champva_form.10_7959c'
    FORM_VERSION = 'vha_10_7959c_rev2025'

    include Vets::Model
    include Attachments
    include StampableLogging

    attribute :data, Hash
    attr_reader :form_id, :uuid

    ##
    # Initializes the form with automatic data transformation.
    # Handles incoming data in any of these formats:
    # 1. Raw submission with `applicants` array (standalone or from 10-10d extended)
    # 2. Pre-flattened data with `applicant_primary_*` fields already set
    #
    # @param data [Hash] Form data in any supported format
    def initialize(data)
      @uuid = SecureRandom.uuid
      @form_id = 'vha_10_7959c_rev2025'
      @data = transform_data(data)
    end

    def desired_stamps
      return [] unless @data

      initial_stamps
    end

    def metadata
      use_renamed_keys = Flipper.enabled?(:champva_update_metadata_keys)
      name_prefix = use_renamed_keys ? 'sponsor' : 'veteran'
      applicant_prefix = use_renamed_keys ? 'beneficiary' : 'applicant'

      {
        "#{name_prefix}FirstName" => @data.dig('applicant_name', 'first'),
        "#{name_prefix}MiddleName" => @data.dig('applicant_name', 'middle'),
        "#{name_prefix}LastName" => @data.dig('applicant_name', 'last'),
        'fileNumber' => @data['applicant_ssn'],
        'zipCode' => @data.dig('applicant_address', 'postal_code') || '00000',
        'country' => @data.dig('applicant_address', 'country') || 'USA',
        'source' => 'VA Platform Digital Forms',
        'ssn_or_tin' => @data['applicant_ssn'],
        'docType' => @data['form_number'],
        'businessLine' => 'CMP',
        'uuid' => @uuid,
        'primaryContactInfo' => @data['primary_contact_info'],
        'primaryContactEmail' => @data.dig('primary_contact_info', 'email').to_s,
        "#{applicant_prefix}Email" => @data['applicant_email'] || ''
      }
    end

    def track_user_identity
      identity = data['certifier_role']
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('IVC ChampVA Forms - 10-7959C-REV2025 Submission User Identity', identity:)
    end

    def track_current_user_loa(current_user)
      current_user_loa = current_user&.loa&.[](:current) || 0
      StatsD.increment("#{STATS_KEY}.#{current_user_loa}")
      Rails.logger.info('IVC ChampVA Forms - 10-7959C-REV2025 Current User LOA', current_user_loa:)
    end

    def track_email_usage
      email_used = metadata&.dig('primaryContactInfo', 'email') ? 'yes' : 'no'
      StatsD.increment("#{STATS_KEY}.#{email_used}")
      Rails.logger.info('IVC ChampVA Forms - 10-7959C-REV2025 Email Used', email_used:)
    end

    def track_submission(current_user)
      identity = data['certifier_role']
      current_user_loa = current_user&.loa&.[](:current) || 0
      email_used = metadata&.dig('primaryContactInfo', 'email') ? 'yes' : 'no'
      StatsD.increment("#{STATS_KEY}.submission", tags: [
                         "identity:#{identity}",
                         "current_user_loa:#{current_user_loa}",
                         "email_used:#{email_used}",
                         "form_version:#{FORM_VERSION}"
                       ])
      Rails.logger.info('IVC ChampVA Forms - 10-7959C-REV2025 Submission', identity:,
                                                                           current_user_loa:,
                                                                           email_used:,
                                                                           form_version: FORM_VERSION)
    end

    def track_delegate_form(parent_form_id)
      StatsD.increment("#{STATS_KEY}.delegate_form.#{parent_form_id}")
      Rails.logger.info('IVC ChampVA Forms - 10-7959C-REV2025 Delegate Form', parent_form_id:)
    end

    # rubocop:disable Naming/BlockForwarding
    def method_missing(method_name, *args, &block)
      super unless respond_to_missing?(method_name)
      { method: method_name, args: }
    end
    # rubocop:enable Naming/BlockForwarding

    def respond_to_missing?(_method_name, _include_private = false)
      true
    end

    private

    ##
    # Transforms incoming data to the flat structure expected by the form mapping.
    # Handles:
    # 1. Pre-flattened data - returns as-is
    # 2. Raw submission with applicants array - extracts first applicant and flattens policies
    #
    # @param incoming_data [Hash] Raw form data
    # @return [Hash] Transformed data with flattened insurance policies
    def transform_data(incoming_data)
      return incoming_data if incoming_data.nil?

      # If data already has flat policy fields, it's been pre-transformed
      return incoming_data if data_already_transformed?(incoming_data)

      # Extract first applicant and merge with form-level data
      transformed = flatten_applicant_data(incoming_data)

      # Flatten health_insurance array to applicant_primary_* / applicant_secondary_* fields
      health_insurance = transformed['health_insurance'] || []
      map_policy_to_flat_fields(health_insurance[0], transformed, :primary) if health_insurance[0]
      map_policy_to_flat_fields(health_insurance[1], transformed, :secondary) if health_insurance[1]

      if transformed['certifier_role'] == 'applicant'
        transformed['applicant_email_address'] ||= transformed['certifier_email']
      elsif transformed['applicant_email'].present?
        transformed['applicant_email_address'] ||= transformed['applicant_email']
      end

      transformed
    end

    ##
    # Checks if data has already been transformed to flat policy fields.
    #
    # @param incoming_data [Hash] Data to check
    # @return [Boolean] True if data has flat policy fields
    def data_already_transformed?(incoming_data)
      incoming_data.key?('applicant_primary_provider') ||
        incoming_data.key?('applicant_secondary_provider') ||
        incoming_data.key?('applicant_primary_insurance_type')
    end

    ##
    # Extracts first applicant from applicants array and merges with form-level data.
    # If no applicants array exists, returns a copy of the incoming data.
    #
    # @param incoming_data [Hash] Raw form data
    # @return [Hash] Flattened data with applicant fields at root level
    def flatten_applicant_data(incoming_data)
      applicants = incoming_data['applicants']

      if applicants.is_a?(Array) && applicants.first.is_a?(Hash)
        first_applicant = applicants.first
        incoming_data.except('applicants', 'raw_data').merge(first_applicant)
      else
        incoming_data.dup
      end
    end

    ##
    # Maps a single insurance policy to flat form fields.
    #
    # @param policy [Hash] Insurance policy data
    # @param data [Hash] Data hash to update (mutated in place)
    # @param position [Symbol] :primary or :secondary
    def map_policy_to_flat_fields(policy, data, position)
      return unless policy

      prefix = "applicant_#{position}"
      data["#{prefix}_provider"] = policy['provider']
      data["#{prefix}_effective_date"] = policy['effective_date']
      data["#{prefix}_expiration_date"] = policy['expiration_date']
      data["#{prefix}_through_employer"] = policy['through_employer']
      data["#{prefix}_insurance_type"] = policy['insurance_type']
      data["#{prefix}_eob"] = policy['eob']
      data["#{position}_medigap_plan"] = policy['medigap_plan']
      data["#{position}_additional_comments"] = policy['additional_comments']
    end

    def initial_stamps
      signature = @data['statement_of_truth_signature']

      log_missing_stamp_data({
                               'statement_of_truth_signature' => {
                                 value: signature.present? ? 'present' : nil
                               }
                             })

      [
        { coords: [170, 65], text: signature, page: 0 }
      ]
    end
  end
end
