# frozen_string_literal: true

module V0
  class CaveController < ApplicationController
    service_tag 'cave'

    before_action :require_cave_feature_enabled

    rescue_from Idp::Error, with: :render_service_error

    def create
      render json: client.intake(
        file_name: intake_params[:file_name],
        pdf_base64: intake_params[:pdf_b64],
        user_id: idp_user_id
      )
    end

    def status
      render json: client.status(document_id, user_id: idp_user_id)
    end

    def output
      type = params[:type].presence || 'artifact'
      render json: client.output(document_id, type:, user_id: idp_user_id)
    end

    def download
      kvpid = params.require(:kvpid)
      render json: client.download(document_id, kvpid:, user_id: idp_user_id)
    end

    private

    def intake_params
      params.require(:pdf_b64)
      params.require(:file_name)
      params.permit(:pdf_b64, :file_name)
    end

    def document_id
      params.require(:id)
    end

    def client
      @client ||= Idp.client
    end

    def idp_user_id
      user_id = current_user&.user_account_uuid.presence || current_user&.uuid
      return user_id if user_id.present?

      raise Common::Exceptions::Forbidden, detail: 'Unable to determine user identity for IDP request'
    end

    def require_cave_feature_enabled
      routing_error unless Flipper.enabled?(:cave_idp)
    end

    def render_service_error(error)
      log_exception_to_sentry(
        error,
        { cave_document_id: params[:id], cave_endpoint: request.path }
      )

      render json: {
        errors: [
          {
            detail: 'Document processing service is temporarily unavailable'
          }
        ]
      }, status: :bad_gateway
    end
  end
end
