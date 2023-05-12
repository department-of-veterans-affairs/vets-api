# frozen_string_literal: true

require 'forms_api_submission/service'

module FormsApi
  module V1
    class UploadsController < ApplicationController
      skip_before_action :authenticate
      skip_after_action :set_csrf_header

      FORM_NUMBER_MAP = {
        '21-10210' => 'vba_21_10210',
        '21-4142' => 'vba_21_4142',
        '26-4555' => 'vba_26_4555',
        '10-10D' => 'vha_10_10d'
      }.freeze

      def submit
        form_id = FORM_NUMBER_MAP[params[:form_number]]
        filler = FormsApi::PdfFiller.new(form_number: form_id, data: JSON.parse(params.to_json))

        file_path = filler.generate
        metadata = filler.metadata

        status, confirmation_number = upload_pdf_to_benefits_intake(file_path, metadata)

        Rails.logger.info(
          "Forms api - sent to benefits intake: #{params[:form_number]}, status: #{status}, uuid #{confirmation_number}"
        )
        render json: { confirmation_number: }, status:
      rescue => e
        # scrubs all user-entered info from the error message
        param_hash = JSON.parse(params.to_json)
        remove_words(param_hash, e.message)
        raise e
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
        lighthouse_service = FormsApiSubmission::Service.new
        uuid_and_location = get_upload_location_and_uuid(lighthouse_service)

        response = lighthouse_service.upload_doc(
          upload_url: uuid_and_location[:location],
          file: file_path,
          metadata: metadata.to_json
        )

        [response.status, uuid_and_location[:uuid]]
      end

      def aggregate_words(hash)
        words = []
        hash.each_value do |value|
          case value
          when Hash
            words += aggregate_words(value)
          when String
            words += value.split
          end
        end
        words.uniq.sort_by(&:length).reverse
      end

      def remove_words(hash, message)
        words_to_remove = aggregate_words(hash)
        words_to_remove.each do |word|
          message.gsub!(word, '')
        end
        message
      end
    end
  end
end
