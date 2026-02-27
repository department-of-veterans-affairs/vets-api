# frozen_string_literal: true

module SimpleFormsApi
  module Mms
    class IbmUploadJob
      include Sidekiq::Job

      sidekiq_options retry: 10, backtrace: true

      def sidekiq_retries_exhausted(msg)
        begin
          form_no = msg['args'].second
          comf_no = msg['args'].third
        rescue
          form_no = 'NOT FOUND'
          comf_no = 'NOT FOUND'
        end

        Rails.logger.error(
          'Sidekiq: Simple Forms API - MMS IbmUploadJob retries exhausted',
          guid: comf_no,
          form_number: form_no
        )
      end

      def perform(ibm_payload, form_number, confirmation_number)
        ibm_service = Ibm::Service.new
        ibm_response = ibm_service.upload_form(
          form: ibm_payload.to_json,
          guid: confirmation_number
        )

        handle_response(ibm_response, form_number, confirmation_number)
      rescue => e
        Rails.logger.error(
          "Simple Forms API - MMS submission failed: #{e.message}",
          guid: confirmation_number,
          form_number:
        )
      end

      private

      def handle_response(ibm_response, form_number, confirmation_number)
        if ibm_response && ibm_response.status == 200
          Rails.logger.info(
            'Simple Forms API - MMS submission complete',
            guid: confirmation_number,
            form_number:
          )
        elsif ibm_response
          Rails.logger.error(
            "Simple Forms API - MMS submission failed: IBM upload returned status #{ibm_response.status}",
            guid: confirmation_number,
            form_number:
          )
        else
          Rails.logger.error(
            'Simple Forms API - MMS submission failed: IBM upload returned no response',
            guid: confirmation_number,
            form_number:
          )
        end
      end
    end
  end
end
