# frozen_string_literal: true

module TravelPay
  module V0
    class DocumentsController < ApplicationController
      rescue_from Common::Exceptions::BadRequest, with: :render_bad_request

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
        document = params[:document] || params[:Document] # accept capital D from API

        validate_claim_id_exists!(claim_id)
        validate_document_exists!(document)

        Rails.logger.info(
          message: "Creating attachment for claim #{claim_id.slice(0, 8)}"
        )

        document_id = service.upload_document(claim_id, document)

        render json: { documentId: document_id }, status: :created
      rescue Common::Exceptions::BadRequest => e
        render json: { errors: [{ detail: e.detail }] }, status: :bad_request
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

      def render_bad_request(e)
        render json: { errors: [{ detail: e.detail }] }, status: :bad_request
      end

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
        return if Flipper.enabled?(:travel_pay_enable_complex_claims, @current_user)

        message = 'Travel Pay expense submission unavailable per feature toggle'
        Rails.logger.error(message:)
        raise Common::Exceptions::ServiceUnavailable, message:
      end

      def validate_claim_id_exists!(claim_id)
        # NOTE: In request specs, you can’t make params[:claim_id] truly missing because
        # it’s part of the URL path and Rails routing prevents that.
        if claim_id.blank?
          raise Common::Exceptions::BadRequest, detail: 'Claim ID is required'
        end

        unless claim_id =~ /\A[\w-]+\z/
          raise Common::Exceptions::BadRequest, detail: 'Claim ID is invalid'
        end
      end

      def validate_document_exists!(document)
        return if document.present?

        raise Common::Exceptions::BadRequest, detail: 'Document is required'
      end
    end
  end
end
