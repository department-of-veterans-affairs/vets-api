# frozen_string_literal: true

require 'central_mail/utilities'
require 'central_mail/service'
require 'pdf_info'

module FormsApi
  module V1
    class UploadsController < ApplicationController
      include CentralMail::Utilities
      skip_before_action :authenticate
      skip_after_action :set_csrf_header

      FORM_NUMBER_MAP = {
        '26-4555' => 'vba_26_4555',
        '10-10D' => 'vha_10_10d'
      }.freeze

      def submit
        form_id = FORM_NUMBER_MAP[params[:form_number]]
        filler = FormsApi::PdfFiller.new(form_number: form_id, data: JSON.parse(params.to_json))

        file_path = filler.generate
        metadata = filler.metadata
        file_name = "#{form_id}.pdf"

        central_mail_service = CentralMail::Service.new
        filled_form = {
          'metadata' => metadata.to_json,
          'document' => filler.to_faraday_upload(file_path, file_name)
        }
        response = central_mail_service.upload(filled_form)

        render json: { message: response.body, confirmation_number: metadata['uuid'] }, status: response.status
      end
    end
  end
end
