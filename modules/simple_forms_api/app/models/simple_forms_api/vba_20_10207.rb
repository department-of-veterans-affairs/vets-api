# frozen_string_literal: true

module SimpleFormsApi
  class VBA2010207
    include Virtus.model(nullify_blank: true)
    STATS_KEY = 'api.simple_forms_api.20_10207'

    attribute :data

    def initialize(data)
      @data = data
    end

    def facility_name(index)
      facility = @data['medical_treatments']&.[](index - 1)
      "#{facility&.[]('facility_name')}\\n#{facility_address(index)}" if facility
    end

    def facility_address(index)
      facility = @data['medical_treatments']&.[](index - 1)
      address = facility&.[]('facility_address')
      "#{address&.[]('street')}" \
        "#{address&.[]('city')}, #{address&.[]('state')}\\n#{address&.[]('postal_code')}\\n" \
        "#{address&.[]('country')}"
    end

    def facility_month(index)
      facility = @data['medical_treatments']&.[](index - 1)
      facility&.[]('start_date')&.[](5..6)
    end

    def facility_day(index)
      facility = @data['medical_treatments']&.[](index - 1)
      facility&.[]('start_date')&.[](8..9)
    end

    def facility_year(index)
      facility = @data['medical_treatments']&.[](index - 1)
      facility&.[]('start_date')&.[](0..3)
    end

    def requester_signature
      @data['statement_of_truth_signature'] if %w[veteran non-veteran].include? @data['preparer_type']
    end

    def third_party_signature
      @data['statement_of_truth_signature'] if %w[third-party-veteran
                                                  third-party-non-veteran].include? @data['preparer_type']
    end

    def power_of_attorney_signature
      @data['statement_of_truth_signature'] if @data['third_party_type'] == 'power-of-attorney'
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran_full_name', 'first'),
        'veteranLastName' => @data.dig('veteran_full_name', 'last'),
        'fileNumber' => @data.dig('veteran_id', 'va_file_number').presence || @data.dig('veteran_id', 'ssn'),
        'zipCode' => @data.dig('veteran_mailing_address',
                               'postal_code').presence || @data.dig('non_veteran_mailing_address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def zip_code_is_us_based
      @data.dig('veteran_mailing_address',
                'country') == 'USA' || @data.dig('non_veteran_mailing_address', 'country') == 'USA'
    end

    def handle_attachments(file_path)
      attachments = get_attachments
      if attachments.count.positive?
        combined_pdf = CombinePDF.new
        combined_pdf << CombinePDF.load(file_path)
        attachments.each do |attachment|
          combined_pdf << CombinePDF.load(attachment)
        end

        combined_pdf.save file_path
      end
    end

    def desired_stamps
      coords = if %w[veteran non-veteran].include? data['preparer_type']
                 [[50, 685]]
               elsif data['third_party_type'] == 'power-of-attorney'
                 [[50, 440]]
               elsif %w[third-party-veteran third-party-non-veteran].include? data['preparer_type']
                 [[50, 565]]
               end
      [{ coords:, text: data['statement_of_truth_signature'], page: 4 }]
    end

    def submission_date_stamps
      [
        {
          coords: [460, 710],
          text: 'Application Submitted:',
          page: 2,
          font_size: 12
        },
        {
          coords: [460, 690],
          text: Time.current.in_time_zone('UTC').strftime('%H:%M %Z %D'),
          page: 2,
          font_size: 12
        }
      ]
    end

    def track_user_identity(confirmation_number)
      identity = "#{data['preparer_type']} #{data['third_party_type']}"
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('Simple forms api - 20-10207 submission user identity', identity:, confirmation_number:)
    end

    private

    def get_attachments
      attachments = []

      financial_hardship_documents = @data['financial_hardship_documents']
      als_documents = @data['als_documents']
      medal_award_documents = @data['medal_award_documents']
      pow_documents = @data['pow_documents']
      terminal_illness_documents = @data['terminal_illness_documents']
      vsi_documents = @data['vsi_documents']

      [
        financial_hardship_documents,
        als_documents,
        medal_award_documents,
        pow_documents,
        terminal_illness_documents,
        vsi_documents
      ].compact.each do |documents|
        confirmation_codes = []
        documents&.map { |doc| confirmation_codes << doc['confirmation_code'] }

        PersistentAttachment.where(guid: confirmation_codes).map { |attachment| attachments << attachment.to_pdf }
      end

      attachments
    end
  end
end
