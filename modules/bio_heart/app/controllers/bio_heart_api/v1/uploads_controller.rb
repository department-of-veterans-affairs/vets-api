# frozen_string_literal: true

require 'datadog'
require 'bio_heart_api/form_mapper_registry'

module BioHeartApi
  module V1
    class UploadsController < ::SimpleFormsApi::V1::UploadsController
      after_action :submit_to_ibm_if_successful, only: [:submit]

      def submit
        super
      end

      private

      def submit_to_ibm_if_successful
        return unless Flipper.enabled?(:bio_heart_mms_submit)
        return unless response.successful?

        # Response body is like:
        # "{\"confirmation_number\":\"c44f39ea-29e4-4504-9e7e-12689a51d00a\",\"submission_api\":\"benefitsIntake\"}"
        confirmation_number = extract_confirmation_number(response.body)
        submit_to_ibm(confirmation_number) if confirmation_number
      end

      def submit_to_ibm(confirmation_number)
        mapper = FormMapperRegistry.mapper_for(params[:form_number])
        # We're not treating these as params beyond this point, so unsafe_h should be fine
        ibm_payload = mapper.transform(params.to_unsafe_h)

        ibm_service = Ibm::Service.new
        ibm_response = ibm_service.upload_form(form: ibm_payload.to_json, guid: confirmation_number)
        # The IBM service internally catches errors, so provided we get something back
        # we know it succeeded (that could probably stand to be improved)
        if ibm_response
          Rails.logger.info("BioHeart MMS submission complete: #{confirmation_number}")
        else
          Rails.logger.error('BioHeart MMS submission failed: IBM upload returned no response',
                             form_number: params[:form_number],
                             guid: confirmation_number)
        end
      rescue => e
        if Flipper.enabled?(:bio_heart_mms_logging)
          Rails.logger.error("BioHeart MMS submission failed: #{e.message}",
                             form_number: params[:form_number],
                             guid: confirmation_number)
        end
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
