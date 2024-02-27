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

    def handle_attachments(file_path) # Add file_path as an input parameter
      attachments = get_attachments
      new_file_names = [file_path] 

      if attachments.count.positive?
        attachments.each_with_index do |attachment, index|
          new_file_name = "vha_10_10d-tmp#{index + 1}.pdf" 
          new_file_path = File.join(File.dirname(attachment), new_file_name)
          
          begin
            File.rename(attachment, new_file_path) 
            new_file_names << new_file_name 
          rescue StandardError => e
            puts "Error occurred while handling attachment: #{e.message}"
          end
        end
      end
      return new_file_names
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
