# frozen_string_literal: true

require 'digital_forms_api/validation/schema'

# Digital Forms API namespace.
module DigitalFormsApi
  # Validation helpers for Digital Forms API request construction.
  module Validation
    # Builds and validates the submissions request body sent to Digital Forms API.
    #
    # Validation is driven by schema fetched from the endpoint:
    # - if endpoint schema defines an envelope, validate the full request
    # - otherwise validate only the payload against the fetched form schema
    class SubmissionRequest
      # Validate and return a submission request payload.
      #
      # @param payload [Hash] structured form payload to submit
      # @param metadata [Hash] envelope metadata for the submission
      # @param form_schema [Hash] schema fetched from Forms API
      # @return [Hash] validated submission request
      # @raise [JSON::Schema::ValidationError] when schema validation fails
      def validate(payload:, metadata:, form_schema:)
        request = build_request(payload:, metadata:)

        if request_schema?(form_schema)
          DigitalFormsApi::Validation.validate_against_schema(form_schema, request)
        else
          DigitalFormsApi::Validation.validate_against_schema(form_schema, payload)
        end

        request
      end

      private

      # Build request body in submissions API envelope format.
      #
      # @param payload [Hash] structured form payload to submit
      # @param metadata [Hash] envelope metadata for the submission
      # @return [Hash] request body ready for schema validation and POST
      def build_request(payload:, metadata:)
        {
          envelope: metadata.merge(
            claimantId: { identifierType: 'PARTICIPANTID', value: metadata[:claimantId] || metadata[:veteranId] },
            veteranId: { identifierType: 'PARTICIPANTID', value: metadata[:veteranId] },
            payload:
          )
        }
      end

      # Identify whether the fetched schema expects the full request object.
      #
      # @param schema [Hash, Object] schema fetched from Forms API
      # @return [Boolean] true when schema includes properties.envelope
      def request_schema?(schema)
        return false unless schema.is_a?(Hash)

        schema.dig('properties', 'envelope').is_a?(Hash) || schema.dig(:properties, :envelope).is_a?(Hash)
      end
    end
  end
end
