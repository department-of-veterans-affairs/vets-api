# frozen_string_literal: true

module TravelPay
  class DocumentsService
    def initialize(auth_manager)
      @auth_manager = auth_manager
    end

    def get_document_summaries(claim_id)
      @auth_manager.authorize => { veis_token:, btsss_token: }
      documents_response = client.get_document_ids(veis_token, btsss_token, claim_id)
      documents_response.body['data']
    end

    def download_document(claim_id, doc_id)
      unless claim_id.present? && doc_id.present?
        raise ArgumentError,
              message: "Missing claim ID or document ID, given: claim_id=#{claim_id}, doc_id=#{doc_id}"
      end

      params = { claim_id:, doc_id: }
      @auth_manager.authorize => { veis_token:, btsss_token: }

      response = client.get_document_binary(veis_token, btsss_token, params)

      {
        body: response.body,
        disposition: response.headers['Content-Disposition'],
        type: response.headers['Content-Type'],
        content_length: response.headers['Content-Length'],
        filename: response.headers['Content-Disposition'][/filename="(.+?)"/, 1]
      }
    end

    def upload_document(claim_id, document)
      unless claim_id.present? && document.present?
        raise ArgumentError,
              message:
                "Missing Claim ID or Uploaded Document, given: claim_id=#{claim_id}, document=#{document}"
      end

      validate_document_extension!(document)
      validate_document_size!(document)

      params = { claim_id:, document: }
      @auth_manager.authorize => { veis_token:, btsss_token: }

      documents_response = client.add_document(veis_token, btsss_token, params)

      documents_response.body['data']
    end

    def delete_document(claim_id, document_id)
      unless claim_id.present? && document_id.present?
        raise ArgumentError,
              message:
              'Missing Claim ID or Document ID, given: ' \
              "claim_id=#{claim_id&.first(8)}, document_id=#{document_id&.first(8)}"
      end

      params = { claim_id:, document_id: }
      @auth_manager.authorize => { veis_token:, btsss_token: }

      documents_response = client.delete_document(veis_token, btsss_token, params)

      documents_response.body['data']
    end

    private

    def client
      TravelPay::DocumentsClient.new
    end

    def validate_document_extension!(document)
      return if document.blank?

      allowed_extensions = %w[pdf jpeg jpg png gif bmp tif tiff doc docx]
      # Allow HEIC/HEIF when conversion is enabled
      allowed_extensions += %w[heic heif] if Flipper.enabled?(:travel_pay_enable_heic_conversion)

      # Extract the extension from the original filename
      extension = File.extname(document.original_filename).delete('.').downcase

      return if allowed_extensions.include?(extension)

      message = "Invalid document type: .#{extension}. Allowed types are: #{allowed_extensions.join(', ')}"
      Rails.logger.error(message)
      raise Common::Exceptions::BadRequest.new(detail: message)
    end

    def validate_document_size!(document)
      return if document.blank?

      max_size_in_bytes = 5.megabytes
      file_size = document.size

      if file_size > max_size_in_bytes
        message = "Uploaded document size (#{file_size} bytes) exceeds the 5 MB limit."
        Rails.logger.error(message)
        raise Common::Exceptions::BadRequest.new(detail: message)
      end
    end
  end
end
