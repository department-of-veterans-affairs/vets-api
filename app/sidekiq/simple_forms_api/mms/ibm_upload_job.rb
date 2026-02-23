# frozen_string_literal: true

module SimpleFormsApi
  module Mms
    class IbmUploadJob
      include Sidekiq::Job

      sidekiq_options retry: 10, backtrace: true

      HOUR_TO_SEND_NOTIFICATIONS = 9

      def perform(ibm_payload, form_number, confirmation_number)
        ibm_service = Ibm::Service.new
        ibm_response = ibm_service.upload_form(
          form: ibm_payload.to_json,
          guid: confirmation_number
        )

        if ibm_response
          Rails.logger.info(
            'Simple Forms API - MMS submission complete',
            guid: confirmation_number,
            form_number: form_number
          )
        else
          Rails.logger.error(
            'Simple Forms API - MMS submission failed: IBM upload returned no response',
            guid: confirmation_number,
            form_number: form_number
          )
        end
      rescue => e
        Rails.logger.error(
          "Simple Forms API - MMS submission failed: #{e.message}",
          guid: confirmation_number,
          form_number: form_number
        )
	  end
    end
  end
end


		