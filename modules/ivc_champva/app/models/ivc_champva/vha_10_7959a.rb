# frozen_string_literal: true

module IvcChampva
  class VHA107959a
    ADDITIONAL_PDF_KEY = 'claims'
    ADDITIONAL_PDF_COUNT = 1
    STATS_KEY = 'api.ivc_champva_form.10_7959a'

    include Virtus.model(nullify_blank: true)
    include Attachments

    attribute :data
    attr_reader :form_id

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
      @form_id = 'vha_10_7959a'
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('applicant_name', 'first'),
        'veteranLastName' => @data.dig('applicant_name', 'last'),
        'zipCode' => @data.dig('applicant_address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP',
        'ssn_or_tin' => @data['applicant_member_number'],
        'member_number' => @data['applicant_member_number'],
        'fileNumber' => @data['applicant_member_number'],
        'country' => @data.dig('applicant_address', 'country') || 'USA',
        'uuid' => @uuid,
        'primaryContactInfo' => @data['primary_contact_info'],
        'primaryContactEmail' => @data.dig('primary_contact_info', 'email').to_s
      }.merge(add_resubmission_properties)
    end

    def add_resubmission_properties
      # TODO: When the frontend adds the actual PDI number field, add to this list
      @data.slice('claim_status', 'pdi_or_claim_number', 'claim_type', 'provider_name', 'beginning_date_of_service',
                  'end_date_of_service', 'medication_name', 'prescription_fill_date')
    end

    ##
    # Informs pdf stamper that we want to stamp some arbitrary values on a blank page
    # in the main form PDF file. See IvcChampva::PdfStamper.add_blank_page_and_stamp
    # @return [Hash] hash of keys/values we want to stamp on a blank page
    def stamp_metadata
      # If it's a resubmission, we want to stamp resubmission-specific values on a blank
      # page in the PDF
      add_resubmission_properties if @data['claim_status'] == 'resubmission'
    end

    def desired_stamps
      [{ coords: [250, 105], text: data['statement_of_truth_signature'], page: 0 }]
    end

    def submission_date_stamps
      [
        {
          coords: [300, 105],
          text: Time.current.in_time_zone('UTC').strftime('%H:%M %Z %D'),
          page: 1,
          font_size: 12
        }
      ]
    end

    def track_user_identity
      identity = data['certifier_role']
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('IVC ChampVA Forms - 10-7959A Submission User Identity', identity:)
    end

    def track_current_user_loa(current_user)
      current_user_loa = current_user&.loa&.[](:current) || 0
      StatsD.increment("#{STATS_KEY}.#{current_user_loa}")
      Rails.logger.info('IVC ChampVA Forms - 10-7959A Current User LOA', current_user_loa:)
    end

    def track_email_usage
      email_used = metadata&.dig('primaryContactInfo', 'email') ? 'yes' : 'no'
      StatsD.increment("#{STATS_KEY}.#{email_used}")
      Rails.logger.info('IVC ChampVA Forms - 10-7959A Email Used', email_used:)
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
  end
end
