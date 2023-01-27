# frozen_string_literal: true

require 'central_mail/utilities'
require 'central_mail/service'
require 'pdf_info'

module FormsApi
  module V1
    class UploadsController < ApplicationController
      include CentralMail::Utilities
      skip_before_action :authenticate
      skip_before_action :verify_authenticity_token
      skip_after_action :set_csrf_header

      def submit
        filler = FormsApi::PdfFiller.new(form_number: params[:form_number], data: JSON.parse(params.to_json))

        file_path = filler.generate

        central_mail_service = CentralMail::Service.new
        filled_form = {
          'metadata' => filler.metadata,
          'document' => filler.to_faraday_upload(file_path, params[:form_number])
        }
        response = central_mail_service.upload(filled_form)

        render json: { status: 'success', message: response.body }
      end
    end
  end
end
