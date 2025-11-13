# frozen_string_literal: true

module V0
  class IdpDocumentsController < ApplicationController
    service_tag 'survivors-benefits'
    skip_before_action :authenticate

    rescue_from Idp::Client::Error, with: :render_service_error

    def create
      render json: client.intake(file_name: intake_params[:file_name], pdf_base64: intake_params[:pdf_b64])
    end

    def status
      render json: client.status(document_id)
    end

    def output
      type = params[:type].presence || 'artifact'
      render json: client.output(document_id, type: type)
    end

    def download
      kvpid = params.require(:kvpid)
      render json: client.download(document_id, kvpid: kvpid)
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
      @client ||= Idp::Client.new
    end

    def render_service_error(error)
      log_exception_to_sentry(
        error,
        { idp_document_id: params[:id], idp_endpoint: request.path }
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
