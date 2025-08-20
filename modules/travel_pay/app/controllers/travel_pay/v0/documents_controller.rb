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
        byebug
        verify_feature_flag_enabled!
        validate_claim_id_exists!
        validate_document_exists!

        # TODO: Maybe we can add the file name to the rails logger?
        Rails.logger.info(
          message: "Creating attachment for claim #{claim_id.slice(0, 8)}"
        )

        # Should we verify the claim id exists? - no not right now
        # Verify the document is valid
        # Add file extension, file size
        # Validate the file extensions (kevin will provide to me) and file size (5 MB limit)
        # Call the service with claim_id and document
        document_id = service.upload_document(params[:claim_id], params[:document])
        # return the documentId and success response
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

      def verify_feature_flag_enabled!
        byebug
        return if Flipper.enabled?(:travel_pay_complex_claims, @current_user)

        message = 'Travel Pay expense submission unavailable per feature toggle'
        Rails.logger.error(message:)
        raise Common::Exceptions::ServiceUnavailable, message:
      end

      def validate_claim_id_exists!
        return if params[:claim_id].present?

        raise Common::Exceptions::BadRequest, detail: 'Claim ID is required'
      end

      def validate_document_exists!
        return if params[:document].present?

        raise Common::Exceptions::BadRequest, detail: 'Document is required'
      end
    end
  end
end
