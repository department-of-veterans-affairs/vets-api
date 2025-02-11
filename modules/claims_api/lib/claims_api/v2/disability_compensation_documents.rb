# frozen_string_literal: true

require 'sidekiq'
require 'claims_api/vbms_uploader'
require 'claims_api/poa_vbms_sidekiq'

module ClaimsApi
  module V2
    class DisabilityCompensationDocuments
      EVSS_DOCUMENT_TYPE = 'L023'

      def initialize(params, claim)
        @params = params
        @claim = claim
      end

      def process_documents
        documents.each do |document|
          claim_document = @claim.supporting_documents.build
          claim_document.set_file_data!(document, EVSS_DOCUMENT_TYPE, @params[:description])
          claim_document.save!
          unless Flipper.enabled? :claims_load_testing
            ClaimsApi::ClaimUploader.perform_async(claim_document.id,
                                                   'document')
          end
        end
      end

      def documents
        document_keys = @params.keys.select { |key| key.include? 'attachment' }
        @documents ||= @params.slice(*document_keys).values.map do |document|
          case document
          when String
            document.blank? ? nil : decode_document(document)
          when ActionDispatch::Http::UploadedFile
            document.original_filename = create_unique_filename(doc: document)
            document
          else
            document
          end
        end.compact
      end

      def decode_document(document)
        base64 = document.split(',').last
        decoded_data = Base64.decode64(base64)
        filename = "temp_upload_#{SecureRandom.urlsafe_base64(8)}.pdf"
        temp_file = Tempfile.new(filename, encoding: 'ASCII-8BIT')
        temp_file.write(decoded_data)
        temp_file.close
        ActionDispatch::Http::UploadedFile.new(filename:,
                                               type: 'application/pdf',
                                               tempfile: temp_file)
      end

      # We have no control over the names of the binary attachments that the consumer gives us.
      # Ensure each attachment we're given has a unique filename so we don't overwrite anything already stored in S3.
      # See API-15088 for context
      def create_unique_filename(doc:)
        original_filename = doc.original_filename
        file_extension = File.extname(original_filename)
        base_filename = File.basename(original_filename, file_extension)
        "#{base_filename}_#{SecureRandom.urlsafe_base64(8)}#{file_extension}"
      end
    end
  end
end
