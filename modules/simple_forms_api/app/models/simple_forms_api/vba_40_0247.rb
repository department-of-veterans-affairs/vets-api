# frozen_string_literal: true

module SimpleFormsApi
  class VBA400247
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran_full_name', 'first'),
        'veteranLastName' => @data.dig('veteran_full_name', 'last'),
        'fileNumber' => @data.dig('veteran_id', 'va_file_number').presence || @data.dig('veteran_id', 'ssn'),
        'zipCode' => @data.dig('applicant_address', 'postal_code') || '00000',
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
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

    def track_user_identity;end

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
  end
end
