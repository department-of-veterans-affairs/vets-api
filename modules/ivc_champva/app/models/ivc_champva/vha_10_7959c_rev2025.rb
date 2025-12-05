# frozen_string_literal: true

# This is a copy of the original 10-7959c form class, but extended
# to point to the 2025 revision of the form + include a signature stamp.
# This is here because we're not ready to get rid of the original 10-7959c
# (the frontend for the standalone form doesn't line up with the 2025 revision).
#
# This version of the form is used with the new 10-10d/10-7959c merged form
# experience (e.g., "10-10D-EXTENDED").

require 'vets/model'

module IvcChampva
  class VHA107959cRev2025
    STATS_KEY = 'api.ivc_champva_form.10_7959c_rev2025'

    include Vets::Model
    include Attachments
    include StampableLogging

    attribute :data, Hash
    attr_reader :form_id

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
      @form_id = 'vha_10_7959c_rev2025'
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
