# frozen_string_literal: true

module SimpleFormsApi
  class VHA1010d
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_claim_number').presence || @data.dig('veteran', 'ssn_or_tin'),
        'zipCode' => @data.dig('veteran', 'address', 'postal_code') || '00000',
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def handle_attachments(file_path)
      attachments = get_attachments
        begin
         split_pdf = CombinePDF.split(file_path) # Split into multiple PDFs
         attachments.each_with_index do |page, index| # Access and process individual PDF pages
         page.save("output_page_#{index + 1}.pdf")     # Example: Save each page as a separate file
        end
      rescue CombinePDF::ParsingError => e 
        puts "Error splitting PDF: #{e.message}"
      end
    end

    def submission_date_config
      { should_stamp_date?: false }
    end

    def track_user_identity; end

    private

    def get_attachments
      attachments = []

      # TODO: We need to look into generatings individual PDFs for each
      # attachment based on what PEGA needs
      supporting_documents = @data['supporting_docs']
      if supporting_documents
        confirmation_codes = []
        supporting_documents&.map { |doc| confirmation_codes << doc['confirmation_code'] }
        PersistentAttachment.where(guid: confirmation_codes).map { |attachment| attachments << attachment.to_pdf }
      end

      attachments
    end
  end
end
