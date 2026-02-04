# frozen_string_literal: true

require 'datadog'
require 'bio_heart_api/form_mapper_registry'

module BioHeartApi
  module V1
    class UploadsController < ::SimpleFormsApi::V1::UploadsController
      def submit
        # If successful, result is a stringified JSON object like:
        # "{\"confirmation_number\":\"c44f39ea-29e4-4504-9e7e-12689a51d00a\",\"submission_api\":\"benefitsIntake\"}"
        result = super # SimpleFormsApi handles generating PDF and submitting to benefits intake

        # If we have a confirmation_number, we successfully submitted to benefits intake API, so
        # go ahead and submit to MMS (otherwise, just gracefully return result)
        submit_to_ibm(result) if extract_confirmation_number(result)

        result
      end

      private

      def submit_to_ibm(benefits_intake_uuid)
        return unless Flipper.enabled?(:bio_heart_govcio_mms)

        mapper = FormMapperRegistry.mapper_for(params[:form_number])
        # We're not treating these as params beyond this point, so unsafe_h should be fine
        ibm_payload = mapper.transform(params.to_unsafe_h)

        ibm_service = Ibm::Service.new
        ibm_service.upload_form(form: ibm_payload.to_json, guid: benefits_intake_uuid)
        Rails.logger.info("BioHeart MMS submission complete: #{benefits_intake_uuid}")
      rescue => e
        Rails.logger.error("BioHeart MMS submission failed: #{e.message}",
                           form_number: params[:form_number],
                           guid: benefits_intake_uuid)
        # Don't re-raise - submission to Benefits Intake already succeeded
      end

      # Returns benefits intake API confirmation number if present in input, otherwise returns false.
      def extract_confirmation_number(value)
        return false if value.blank?

        # Try to parse as JSON if it's a string
        parsed = if value.is_a?(String)
                   begin
                     JSON.parse(value)
                   rescue JSON::ParserError
                     nil
                   end
                 elsif value.is_a?(Hash)
                   value
                 end

        # Extract confirmation_number if present
        return parsed['confirmation_number'] if parsed.is_a?(Hash) && parsed['confirmation_number'].present?

        false
      end
    end
  end
end
