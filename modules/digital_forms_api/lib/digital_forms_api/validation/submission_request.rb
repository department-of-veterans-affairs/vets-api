# frozen_string_literal: true

require 'digital_forms_api/validation'

# Digital Forms API namespace.
module DigitalFormsApi
  # Validation helpers for Digital Forms API request construction.
  module Validation
    # Builds and validates the submissions request body sent to Digital Forms API.
    #
    # The form_schema validates the payload (actual form data) only.
    # Request structure validation (envelope) is handled separately by the
    # Forms API OpenAPI schema.
    class SubmissionRequest
      # Validate and return a submission request payload.
      #
      # @param payload [Hash] structured form payload to submit
      # @param metadata [Hash] envelope metadata for the submission
      # @param form_schema [Hash] schema fetched from Forms API for payload validation
      # @param request_schema [Hash] schema for submission request envelope validation
      # @return [Hash] validated submission request
      # @raise [JSON::Schema::ValidationError] when schema validation fails
      def validate(payload:, metadata:, form_schema:, request_schema:)
        DigitalFormsApi::Validation.validate_against_schema(form_schema, payload)
        request = build_request(payload:, metadata:)
        DigitalFormsApi::Validation.validate_against_schema(request_schema, request)

        request
      end

      private

      # Build request body in submissions API envelope format.
      #
      # @param payload [Hash] structured form payload to submit
      # @param metadata [Hash] envelope metadata for the submission
      # @return [Hash] request body ready for POST
      def build_request(payload:, metadata:)
        normalized_metadata = normalize_metadata(metadata)

        {
          envelope: normalized_metadata.merge(
            claimantId: {
              identifierType: 'PARTICIPANTID',
              value: normalized_metadata[:claimantId] || normalized_metadata[:veteranId]
            },
            veteranId: { identifierType: 'PARTICIPANTID', value: normalized_metadata[:veteranId] },
            payload:
          )
        }
      end

      # Normalize metadata to symbol keys to avoid mixed string/symbol duplicates.
      # Handles the case where both string and symbol versions of a key may exist
      # by preferring the symbol-keyed value.
      #
      # @param metadata [Hash]
      # @return [Hash]
      def normalize_metadata(metadata)
        result = {}
        metadata.to_h.each do |key, value|
          sym_key = key.respond_to?(:to_sym) ? key.to_sym : key
          result[sym_key] = value unless result.key?(sym_key)
        end
        result
      end
    end
  end
end
