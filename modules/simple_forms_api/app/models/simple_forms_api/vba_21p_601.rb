# frozen_string_literal: true

module SimpleFormsApi
  class VBA21p601 < BaseForm
    STATS_KEY = 'api.simple_forms_api.21p_601'

    def words_to_remove
      veteran_ssn + claimant_phone + claimant_email + spouse_ssn + spouse_date_of_birth +
        remarriage_dates + in_reply_refer_to
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_file_number').presence || format_ssn_for_file_number,
        'zipCode' => @data.dig('claimant', 'address', 'zip_code', 'first5'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def notification_first_name
      data.dig('claimant', 'full_name', 'first')
    end

    def notification_email_address
      data.dig('claimant', 'email')
    end

    def zip_code_is_us_based
      @data.dig('claimant', 'address', 'country') == 'USA'
    end

    def submission_date_stamps(_timestamp = Time.current)
      []
    end

    def desired_stamps
      []
    end

    def track_user_identity(confirmation_number)
      identity = get_form_identity
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('Simple forms api - 21P-601 submission user identity', identity:, confirmation_number:)
    end

    def handle_attachments(file_path)
      attachments = get_attachments
      merged_pdf = HexaPDF::Document.open(file_path)

      if attachments.count.positive?
        attachments.each do |attachment|
          attachment_pdf = HexaPDF::Document.open(attachment)
          attachment_pdf.pages.each do |page|
            merged_pdf.pages << merged_pdf.import(page)
          end
        rescue => e
          Rails.logger.error(
            'Simple forms api - failed to load attachment for 21P-601',
            { message: e.message, attachment: attachment.inspect }
          )
          raise
        end
      end
      merged_pdf.write(file_path, optimize: true)
    end

    private

    def get_attachments
      attachments = []

      supporting_documents = @data['veteran_supporting_documents']
      if supporting_documents
        confirmation_codes = []
        supporting_documents&.map { |doc| confirmation_codes << doc['confirmation_code'] }

        PersistentAttachment.where(guid: confirmation_codes).map { |attachment| attachments << attachment.to_pdf }
      end

      attachments
    end

    def get_form_identity
      # Using relationship as the identity tracker, which is a standard field
      relationship = data.dig('claimant', 'relationship_to_deceased')

      # If user entered freeform text, just track as "other":
      return 'other' unless relationship.in?(%w[executor creditor])

      relationship
    end

    def format_ssn_for_file_number
      ssn_parts = @data.dig('veteran', 'ssn')
      return '' unless ssn_parts

      "#{ssn_parts['first3']}#{ssn_parts['middle2']}#{ssn_parts['last4']}"
    end

    def veteran_ssn
      ssn_parts = data.dig('veteran', 'ssn')
      return [] unless ssn_parts

      [
        ssn_parts['first3'],
        ssn_parts['middle2'],
        ssn_parts['last4']
      ]
    end

    def claimant_phone
      phone_parts = data.dig('claimant', 'phone')
      return [] unless phone_parts

      [
        phone_parts['area_code'],
        phone_parts['prefix'],
        phone_parts['line_number']
      ]
    end

    def claimant_email
      email = data.dig('claimant', 'email')
      return [] unless email

      [
        email&.[](0..19),
        email&.[](20..)
      ].compact
    end

    def spouse_ssn
      ssn_parts = data.dig('remarriage', 'spouse_ssn')
      return [] unless ssn_parts

      [
        ssn_parts['first3'],
        ssn_parts['middle2'],
        ssn_parts['last4']
      ]
    end

    def spouse_date_of_birth
      date_parts = data.dig('remarriage', 'spouse_date_of_birth')
      return [] unless date_parts

      [
        date_parts['year'],
        date_parts['month'],
        date_parts['day']
      ]
    end

    def remarriage_dates
      dates = []

      # Marriage date
      marriage_date = data.dig('remarriage', 'date_of_marriage')
      if marriage_date
        dates += [
          marriage_date['year'],
          marriage_date['month'],
          marriage_date['day']
        ]
      end

      # Termination date (if applicable)
      termination_date = data.dig('remarriage', 'termination_date')
      if termination_date && termination_date['year'].present?
        dates += [
          termination_date['year'],
          termination_date['month'],
          termination_date['day']
        ]
      end

      dates
    end

    def in_reply_refer_to
      refer_to = data['in_reply_refer_to']
      return [] unless refer_to

      [
        refer_to&.[](0..4),
        refer_to&.[](5..)
      ].compact
    end
  end
end
