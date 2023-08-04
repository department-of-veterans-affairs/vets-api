# frozen_string_literal: true

require 'ddtrace'
require 'simple_forms_api_submission/service'

module SimpleFormsApi
  module V1
    class UploadsController < ApplicationController
      skip_before_action :authenticate
      skip_after_action :set_csrf_header

      FORM_NUMBER_MAP = {
        '21-0972' => 'vba_21_0972',
        '21-10210' => 'vba_21_10210',
        '21-4142' => 'vba_21_4142',
        '21P-0847' => 'vba_21p_0847',
        '26-4555' => 'vba_26_4555',
        '10-10D' => 'vha_10_10d'
      }.freeze

      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])

        form_id = FORM_NUMBER_MAP[params[:form_number]]
        filler = SimpleFormsApi::PdfFiller.new(form_number: form_id, data: JSON.parse(params.to_json))

        file_path = filler.generate
        metadata = filler.metadata

        status, confirmation_number = upload_pdf_to_benefits_intake(file_path, metadata)

        Rails.logger.info(
          "Simple forms api - sent to benefits intake: #{params[:form_number]},
            status: #{status}, uuid #{confirmation_number}"
        )
        render json: { confirmation_number: }, status:
      rescue
        raise "something has gone wrong with your form, #{params[:form_number]} and the entire " \
              'error message has been redacted to keep PII from getting leaked'
      end

      private

      def get_upload_location_and_uuid(lighthouse_service)
        upload_location = lighthouse_service.get_upload_location.body
        {
          uuid: upload_location.dig('data', 'id'),
          location: upload_location.dig('data', 'attributes', 'location')
        }
      end

      def upload_pdf_to_benefits_intake(file_path, metadata)
        lighthouse_service = SimpleFormsApiSubmission::Service.new
        uuid_and_location = get_upload_location_and_uuid(lighthouse_service)

        response = lighthouse_service.upload_doc(
          upload_url: uuid_and_location[:location],
          file: file_path,
          metadata: metadata.to_json
        )

        [response.status, uuid_and_location[:uuid]]
      end
    end
  end
end
