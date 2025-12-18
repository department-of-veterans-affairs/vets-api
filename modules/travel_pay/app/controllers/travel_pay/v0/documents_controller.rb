# frozen_string_literal: true

module TravelPay
  module V0
    class DocumentsController < ApplicationController
      include FeatureFlagHelper
      include IdValidation

      rescue_from Common::Exceptions::BadRequest, with: :render_bad_request

      before_action :check_feature_flag, only: %i[create destroy]

      def version_map
        should_upgrade = Flipper.enabled?(:travel_pay_claims_api_v3_upgrade)
        {
          get_document_binary: should_upgrade ? 'v3' : 'v2'
        }
      end

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
        claim_id = params[:claim_id]
        document = params[:document] || params[:Document] # accept capital D from API

        validate_uuid_exists!(claim_id, 'Claim')
        validate_document_exists!(document)

        Rails.logger.info(
          message: "Creating attachment for claim #{claim_id.slice(0, 8)}"
        )
        response_data = service.upload_document(claim_id, document)
        render json: { documentId: response_data['documentId'] }, status: :created
      rescue Faraday::ResourceNotFound => e
        handle_resource_not_found_error(e)
      rescue Faraday::Error => e
        Rails.logger.error("Error uploading document: #{e.message}")
        render json: { error: 'Error uploading document' }, status: e.response[:status]
      end

      def destroy
        claim_id = params[:claim_id]
        document_id = params[:id]

        validate_uuid_exists!(claim_id, 'Claim')
        validate_uuid_exists!(document_id, 'Document')
        # TODO: do we need to verify that the document id is an actual id that exists?

        response_data = service.delete_document(claim_id, document_id)
        render json: { documentId: response_data['documentId'] }, status: :ok
      rescue Faraday::ResourceNotFound => e
        # API 404
        handle_resource_not_found_error(e)
      rescue Faraday::ClientError => e
        # 400-level errors (bad request, unauthorized, forbidden)
        handle_faraday_error(e, 'Client error deleting document', log_prefix: 'Deleting document: ')
      rescue Faraday::ServerError => e
        # 500-level errors
        handle_faraday_error(e, 'Server error deleting document', log_prefix: 'Deleting document: ')
      end

      private

      # Handles Faraday errors for both client (4xx) and server (5xx)
      # e: the Faraday error
      # default_message: fallback message if response body is missing
      # log_prefix: optional prefix for log message
      def handle_faraday_error(e, default_message, log_prefix: '')
        error_type = e.is_a?(Faraday::ClientError) ? 'client' : 'server'
        Rails.logger.error("#{log_prefix}Faraday #{error_type} error: #{e.message}")

        http_status = e.response&.dig(:status) ||
                      (e.is_a?(Faraday::ClientError) ? :bad_request : :internal_server_error)
        message = if e.response&.dig(:body).present?
                    e.response[:body]
                  else
                    default_message
                  end

        render json: { errors: [{ detail: message }] }, status: http_status
      end

      def check_feature_flag
        verify_feature_flag!(
          :travel_pay_enable_complex_claims,
          current_user,
          error_message: 'Travel Pay document endpoint unavailable per feature toggle'
        )
      end

      def render_bad_request(e)
        # Extract the first detail from errors array, fallback to generic
        error_detail = if e.respond_to?(:errors) && e.errors.any?
                         e.errors.first[:detail] || 'Bad request'
                       else
                         'Bad request'
                       end

        render json: { errors: [{ detail: error_detail }] }, status: :bad_request
      end

      def auth_manager
        @auth_manager ||= TravelPay::AuthManager.new(Settings.travel_pay.client_number, @current_user)
      end

      def service
        @service ||= TravelPay::DocumentsService.new(auth_manager, version_map)
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

      def validate_document_exists!(document)
        return if document.present?

        raise Common::Exceptions::BadRequest.new(detail: 'Document is required')
      end
    end
  end
end
