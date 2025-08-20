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
        validate_attachment_exists!

        # TODO: Maybe we can add the file name to the rails logger?
        Rails.logger.info(
          message: "Creating attachment for claim #{claim_id.slice(0, 8)}"
        )
        # Get the document
        uploaded_document = params[:document]

        # Get the claim Id
        claim_id = params[:claim_id]

        # Should we verify the claim id exists? - no not right now
        # Verify the attachment is valid
        # Add file extension, file size
        # Validate the file extensions (kevin will provide to me) and file size (5 MB limit)
        # Call the service with claim_id and attachment
        # document_id = SERVICE(claim_id, attachment)
        # return the documentId and success response
        render json: document_id, status: :created
        rescue Faraday::ResourceNotFound => e
          handle_resource_not_found_error(e)
        rescue Faraday::Error => e
          Rails.logger.error("Error downloading document: #{e.message}")
          render json: { error: 'Error downloading document' }, status: e.response[:status]
        rescue Common::Exceptions::BackendServiceException => e
          Rails.logger.error("Error downloading document: #{e.message}")
          render json: { error: 'Error downloading document' }, status: e.original_status
        end
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
        return if Flipper.enabled?(:travel_pay_complex_claims, @current_user)

        message = 'Travel Pay expense submission unavailable per feature toggle'
        Rails.logger.error(message:)
        raise Common::Exceptions::ServiceUnavailable, message:
      end

      def validate_claim_id_exists!
        return if params[:claim_id].present?

        raise Common::Exceptions::BadRequest, detail: 'Claim ID is required'
      end

      def validate_attachment_exists!
        return if params[:attachment].present?

        raise Common::Exceptions::BadRequest, detail: 'Attachment is required'
      end
    end
  end
end
