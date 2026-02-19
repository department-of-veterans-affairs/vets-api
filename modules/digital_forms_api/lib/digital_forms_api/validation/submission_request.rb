# frozen_string_literal: true

require 'digital_forms_api/validation/schema'

module DigitalFormsApi
  module Validation
    class SubmissionRequest
      def validate(payload:, metadata:, form_schema:)
        request = build_request(payload:, metadata:)

        if request_schema?(form_schema)
          DigitalFormsApi::Validation.validate_against_schema(form_schema, request)
        else
          DigitalFormsApi::Validation.validate_against_schema(form_schema, payload)
        end
      end

      private

      def build_request(payload:, metadata:)
        {
          envelope: metadata.merge(
            claimantId: { identifierType: 'PARTICIPANTID', value: metadata[:claimantId] || metadata[:veteranId] },
            veteranId: { identifierType: 'PARTICIPANTID', value: metadata[:veteranId] },
            payload:
          )
        }
      end

      def request_schema?(schema)
        schema.is_a?(Hash) && schema.dig('properties', 'envelope').is_a?(Hash)
      end
    end
  end
end