# frozen_string_literal: true

module IvcChampva
  class VHA1010d2027
    ADDITIONAL_PDF_KEY = 'applicants'
    ADDITIONAL_PDF_COUNT = 3
    STATS_KEY = 'api.ivc_champva_form.10_10d'
    FORM_VERSION = 'vha_10_10d_2027'

    include Virtus.model(nullify_blank: true)
    include Attachments
    include StampableLogging

    attribute :data
    attr_reader :form_id

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
      @form_id = 'vha_10_10d_2027'
    end

    def metadata # rubocop:disable Metrics/MethodLength
      {
        'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        'veteranMiddleName' => @data.dig('veteran', 'full_name', 'middle'),
        'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        'veteranEmail' => @data.dig('veteran', 'email'),
        'sponsorFirstName' => @data.fetch('applicants', [])&.first&.dig('applicant_name', 'first'),
        'sponsorMiddleName' => @data.fetch('applicants', [])&.first&.dig('applicant_name', 'middle'),
        'sponsorLastName' => @data.fetch('applicants', [])&.first&.dig('applicant_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_claim_number').presence || @data.dig('veteran', 'ssn_or_tin'),
        'zipCode' => @data.dig('veteran', 'address', 'postal_code') || '00000',
        'country' => @data.dig('veteran', 'address', 'country') || 'USA',
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP',
        'ssn_or_tin' => @data.dig('veteran', 'ssn_or_tin'),
        'uuid' => @uuid,
        'primaryContactInfo' => @data['primary_contact_info'],
        'hasApplicantOver65' => @data['has_applicant_over65'].to_s,
        'primaryContactEmail' => @data.dig('primary_contact_info', 'email').to_s,
        'formExpiration' => '12/31/2027'
        # add individual properties for each applicant in the applicants array:
      }.merge(add_applicant_properties)
    end

    def add_applicant_properties
      applicants = @data['applicants']
      return {} if applicants.blank?

      use_renamed_keys = Flipper.enabled?(:champva_update_metadata_keys)
      applicants.each_with_index.with_object({}) do |(app, index), obj|
        if use_renamed_keys
          obj["beneficiary_#{index}"] = extract_beneficiary_properties(app).to_json
        else
          obj["applicant_#{index}"] = extract_applicant_properties(app).to_json
        end
      end
    end

    def desired_stamps
      return [] unless @data

      stamps = initial_stamps
      stamps.concat(applicant_stamps)

      stamps
    end

    def submission_date_stamps
      [
        {
          coords: [40, 500],
          text: Time.current.in_time_zone('UTC').strftime('%H:%M %Z %D'),
          page: 1,
          font_size: 12
        }
      ]
    end

    def track_user_identity
      identity = data['certifier_role']
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('IVC ChampVA Forms - 10-10D-2027 Submission User Identity', identity:)
    end

    def track_current_user_loa(current_user)
      current_user_loa = current_user&.loa&.[](:current) || 0
      StatsD.increment("#{STATS_KEY}.#{current_user_loa}")
      Rails.logger.info('IVC ChampVA Forms - 10-10D-2027 Current User LOA', current_user_loa:)
    end

    def track_email_usage
      email_used = metadata&.dig('primaryContactInfo', 'email') ? 'yes' : 'no'
      StatsD.increment("#{STATS_KEY}.#{email_used}")
      Rails.logger.info('IVC ChampVA Forms - 10-10D-2027 Email Used', email_used:)
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
      Rails.logger.info('IVC ChampVA Forms - 10-10D-2027 Submission', identity:,
                                                                      current_user_loa:,
                                                                      email_used:,
                                                                      form_version: FORM_VERSION)
    end

    def method_missing(_, *args)
      args&.first
    end

    def respond_to_missing?(_method_name, _include_private = false)
      true
    end

    private

    def initial_stamps
      stamps = [
        { coords: [40, 105], text: @data['statement_of_truth_signature'], page: 0 }
      ]
      sponsor_is_deceased = @data.dig('veteran', 'sponsor_is_deceased')
      veteran_country = @data.dig('veteran', 'address', 'country')
      applicants = @data.fetch('applicants', [])
      first_applicant_country = if applicants.is_a?(Array) && !applicants.empty?
                                  applicants.first&.dig('applicant_address', 'country')
                                end

      log_missing_stamp_data({
                               'first_applicant_country' => { value: first_applicant_country },
                               'veteran_country' => {
                                 value: veteran_country,
                                 context: { is_deceased: sponsor_is_deceased, certifier_role: @data['certifier_role'] }
                               }
                             })

      stamps << { coords: [520, 470], text: first_applicant_country, page: 0 }
      stamps << { coords: [520, 590], text: veteran_country, page: 0 } unless sponsor_is_deceased
      stamps << { coords: [420, 45], text: veteran_country, page: 0 } if @data['certifier_role'] == 'sponsor'
      stamps
    end

    def applicant_stamps
      stamps = []
      applicants = @data.fetch('applicants', [])

      applicants.each_with_index do |applicant, index|
        next if index.zero?

        coords_y = 470 - (116 * index)
        applicant_country = applicant.dig('applicant_address', 'country')

        log_missing_field("applicant_#{index}_country") if applicant_country.blank?

        if applicant_country && stamps.count { |stamp| stamp[:text] == applicant_country } < 2
          stamps << { coords: [520, coords_y], text: applicant_country, page: 0 }
        end
      end

      stamps
    end

    def extract_applicant_properties(app)
      app.symbolize_keys.slice(:applicant_ssn, :applicant_name, :applicant_dob)
    end

    def extract_beneficiary_properties(app)
      applicant = app.symbolize_keys.slice(:applicant_ssn, :applicant_name, :applicant_dob)
      applicant.tap do |a|
        a[:beneficiary_ssn] = a.delete(:applicant_ssn)
        a[:beneficiary_name] = a.delete(:applicant_name)
        a[:beneficiary_dob] = a.delete(:applicant_dob)
      end
    end
  end
end
