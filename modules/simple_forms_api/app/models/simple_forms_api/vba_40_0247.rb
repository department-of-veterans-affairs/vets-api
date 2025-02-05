# frozen_string_literal: true

module SimpleFormsApi
  class VBA400247 < BaseForm
    def metadata
      {
        'veteranFirstName' => @data.dig('veteran_full_name', 'first'),
        'veteranLastName' => @data.dig('veteran_full_name', 'last'),
        'fileNumber' => @data.dig('veteran_id', 'va_file_number').presence || @data.dig('veteran_id', 'ssn'),
        'zipCode' => @data.dig('applicant_address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def notification_first_name
      data.dig('applicant_full_name', 'first')
    end

    def notification_email_address
      data['applicant_email']
    end

    def veteran_name
      first_name = data.dig('veteran_full_name', 'first') || ''
      middle_name = data.dig('veteran_full_name', 'middle') || ''
      last_name = data.dig('veteran_full_name', 'last') || ''

      "#{first_name} #{middle_name} #{last_name}"
    end

    def applicant_name
      first_name = data.dig('applicant_full_name', 'first') || ''
      middle_name = data.dig('applicant_full_name', 'middle') || ''
      last_name = data.dig('applicant_full_name', 'last') || ''

      "#{first_name} #{middle_name} #{last_name}"
    end

    def applicant_address
      street = data.dig('applicant_address', 'street') || ''
      street2 = data.dig('applicant_address', 'street2') || ''
      city = data.dig('applicant_address', 'city') || ''
      state = data.dig('applicant_address', 'state') || ''
      postal_code = data.dig('applicant_address', 'postal_code') || ''
      country = data.dig('applicant_address', 'country') || ''

      "#{street}, #{street2}\\n#{city}, #{state} #{postal_code} #{country}"
    end

    def zip_code_is_us_based
      @data.dig('applicant_address', 'country') == 'USA'
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
            'Simple forms api - failed to load attachment for 40-0247',
            { message: e.message, attachment: attachment.inspect }
          )
          raise
        end
      end
      merged_pdf.write(file_path, optimize: true)
    end

    def words_to_remove
      veteran_ssn_and_file_number + veteran_dates_of_birth_and_death + applicant_zip + applicant_phone
    end

    def desired_stamps
      []
    end

    def submission_date_stamps(_timestamp)
      []
    end

    def track_user_identity(confirmation_number); end

    private

    def get_attachments
      attachments = []

      additional_address = @data['additional_address']
      if additional_address
        file_path = fill_pdf_with_additional_address
        attachments << file_path
      end

      supporting_documents = @data['veteran_supporting_documents']
      if supporting_documents
        confirmation_codes = []
        supporting_documents&.map { |doc| confirmation_codes << doc['confirmation_code'] }

        PersistentAttachment.where(guid: confirmation_codes).map { |attachment| attachments << attachment.to_pdf }
      end

      attachments
    end

    def fill_pdf_with_additional_address
      additional_form_data = @data
      additional_form_data['applicant_address'] = {
        'street' => additional_form_data.dig('additional_address', 'street'),
        'city' => additional_form_data.dig('additional_address', 'city'),
        'state' => additional_form_data.dig('additional_address', 'state'),
        'postal_code' => additional_form_data.dig('additional_address', 'postal_code'),
        'country' => additional_form_data.dig('additional_address', 'country')
      }
      additional_form_data['certificates'] = additional_form_data['additional_copies']
      filler = SimpleFormsApi::PdfFiller.new(
        form_number: 'vba_40_0247',
        form: SimpleFormsApi::VBA400247.new(additional_form_data),
        name: 'vba_40_0247_additional_address'
      )

      filler.generate
    end

    def veteran_ssn_and_file_number
      [
        data.dig('veteran_id', 'ssn')&.[](0..2),
        data.dig('veteran_id', 'ssn')&.[](3..4),
        data.dig('veteran_id', 'ssn')&.[](5..8),
        data.dig('veteran_id', 'va_file_number')&.[](0..2),
        data.dig('veteran_id', 'va_file_number')&.[](3..4),
        data.dig('veteran_id', 'va_file_number')&.[](5..8)
      ]
    end

    def veteran_dates_of_birth_and_death
      [
        data['veteran_date_of_birth']&.[](0..3),
        data['veteran_date_of_birth']&.[](5..6),
        data['veteran_date_of_birth']&.[](8..9),
        data['veteran_date_of_death']&.[](0..3),
        data['veteran_date_of_death']&.[](5..6),
        data['veteran_date_of_death']&.[](8..9)
      ]
    end

    def applicant_zip
      [
        data.dig('applicant_address', 'postal_code')&.[](0..4),
        data.dig('applicant_address', 'postal_code')&.[](5..8)
      ]
    end

    def applicant_phone
      [
        data['applicant_phone']&.gsub('-', '')&.[](0..2),
        data['applicant_phone']&.gsub('-', '')&.[](3..5),
        data['applicant_phone']&.gsub('-', '')&.[](6..9)
      ]
    end
  end
end
