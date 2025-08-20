# frozen_string_literal: true

module TravelPay
  module V0
    class DocumentsController < ApplicationController
      def show
        document_data = service.download_document(params[:claim_id], params[:id])

        send_data(
          document_data[:body],
          type: document_data[:type],
          disposition: document_data[:disposition],
          filename: document_data[:filename]
        )
      rescue Faraday::ResourceNotFound => e
        handle_resource_not_found_error(e)
      rescue Faraday::Error => e
        Rails.logger.error("Error downloading document: #{e.message}")
        render json: { error: 'Error downloading document' }, status: e.response[:status]
      rescue Common::Exceptions::BackendServiceException => e
        Rails.logger.error("Error downloading document: #{e.message}")
        render json: { error: 'Error downloading document' }, status: e.original_status
      end

      def create
        verify_feature_flag_enabled!

        claim_id = params[:claim_id]
        document = params[:document]

        validate_params!(claim_id, document)
        

        Rails.logger.info(
          message: "Creating attachment for claim #{claim_id.slice(0, 8)}"
        )

        # Call the service with claim_id and document
        document_id = service.upload_document(claim_id, document)

        render json: { documentId: document_id }, status: :created
      rescue Faraday::ResourceNotFound => e
        handle_resource_not_found_error(e)
      rescue Faraday::Error => e
        Rails.logger.error("Error downloading document: #{e.message}")
        render json: { error: 'Error downloading document' }, status: e.response[:status]
      rescue Common::Exceptions::BackendServiceException => e
        Rails.logger.error("Error downloading document: #{e.message}")
        render json: { error: 'Error downloading document' }, status: e.original_status
      end

      private

      def auth_manager
        @auth_manager ||= TravelPay::AuthManager.new(Settings.travel_pay.client_number, @current_user)
      end

      def service
        @service ||= TravelPay::DocumentsService.new(auth_manager)
      end

      def handle_resource_not_found_error(e)
        Rails.logger.error("Document not found: #{e.message}")
        render(
          json: {
            error: 'Document not found',
            correlation_id: e.response[:request][:headers]['X-Correlation-ID']
          },
          status: :not_found
        )
      end

      def validate_params!(claim_id, document)
        validate_claim_id_exists!(claim_id)
        validate_document_exists!(document)
        validate_document_extension!(document)
        validate_document_size!(document)
      end

      def verify_feature_flag_enabled!
        return if Flipper.enabled?(:travel_pay_enable_complex_claims, @current_user)

        message = 'Travel Pay expense submission unavailable per feature toggle'
        Rails.logger.error(message:)
        raise Common::Exceptions::ServiceUnavailable, message:
      end

      def validate_claim_id_exists!(claim_id)
        return if claim_id.present?

        raise Common::Exceptions::BadRequest, detail: 'Claim ID is required'
      end

      def validate_document_exists!(document)
        return if document.present?

        raise Common::Exceptions::BadRequest, detail: 'Document is required'
      end

      def validate_document_extension!(document)
        return if document.blank?

        allowed_extensions = %w[pdf jpeg jpg png gif bmp tif tiff doc docx]

        # Extract the extension from the original filename
        extension = File.extname(document.original_filename).delete('.').downcase

        return if allowed_extensions.include?(extension)

        message = "Invalid document type: .#{extension}. Allowed types are: #{allowed_extensions.join(', ')}"
        Rails.logger.error(message)
        raise Common::Exceptions::BadRequest, detail: message
      end

      def validate_document_size!(document)
        return if document.blank?

        max_size_in_bytes = 5.megabytes
        file_size = document.size

        if file_size > max_size_in_bytes
          message = "Uploaded document size (#{file_size} bytes) exceeds the 5 MB limit."
          Rails.logger.error(message)
          raise Common::Exceptions::BadRequest, detail: message
        end
      end
    end
  end
end
