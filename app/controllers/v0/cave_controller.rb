# frozen_string_literal: true

module V0
  class CaveController < ApplicationController
    service_tag 'cave'

    before_action :require_cave_feature_enabled
    before_action :require_survivors_benefits_idp_enabled

    rescue_from Idp::Error, with: :render_service_error

    def create
      render json: client.intake(file_name: intake_params[:file_name], pdf_base64: intake_params[:pdf_b64])
    end

    def status
      render json: client.status(document_id)
    end

    def output
      type = params[:type].presence || 'artifact'
      render json: client.output(document_id, type:)
    end

    def download
      kvpid = params.require(:kvpid)
      render json: client.download(document_id, kvpid:)
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

    def require_cave_feature_enabled
      routing_error unless Flipper.enabled?(:cave_idp)
    end

    def require_survivors_benefits_idp_enabled
      return if Flipper.enabled?(:survivors_benefits_idp, current_user)

      raise Common::Exceptions::Forbidden, detail: 'IDP access is not enabled for this user'
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
