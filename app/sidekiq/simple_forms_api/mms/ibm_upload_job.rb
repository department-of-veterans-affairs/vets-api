# frozen_string_literal: true

module SimpleFormsApi
  module Mms
    class IbmUploadJob
      include Sidekiq::Job

      sidekiq_options retry: 10, backtrace: true

      sidekiq_retries_exhausted do |msg, ex|
        begin
          form_no = msg['args'].second
          comf_no = msg['args'].third
        rescue
          form_no = 'NOT FOUND'
          comf_no = 'NOT FOUND'
        end

        Rails.logger.error(
          'Sidekiq retries exhausted for SimpleForms::API::MMS::IbmUploadJob - ' \
          "#{ex.class}: #{ex.message}",
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

        handle_response(ibm_response)
      rescue => e
        Rails.logger.error(
          "Simple Forms API - MMS submission failed: #{e.message}",
          guid: confirmation_number,
          form_number:
        )
        raise
      end

      private

      def handle_response(ibm_response)
        return if ibm_response&.status == 200

        reason =
          if ibm_response
            "IBM upload returned status #{ibm_response.status}"
          else
            'IBM upload returned no response'
          end

        raise StandardError, reason
      end
    end
  end
end
