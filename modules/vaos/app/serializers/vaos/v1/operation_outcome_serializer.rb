# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module V1
    # FHIR (DSTU 2) Operation Outcome serializer. Follows the interface of ActiveModel Serializers.
    # FHIR errors when interacting with resources are wrapped in Operation Outcomes
    # http://hl7.org/fhir/DSTU2/operationoutcome.html
    #
    # The issue must first be wrapped in a VAOS::V1::OperationOutcome which is passed to the serializer.
    # This serializer takes errors that intended for JSON API rendering and remaps their fields.
    #
    # @example Serialize a BackendServiceException as an outcome
    #   issue = Common::Exceptions::BackendServiceException.new('VAOS_502', source: 'Klass')
    #   operation_outcome = VAOS::V1::OperationOutcome.new(resource_type: resource_type, id: id, issue: issue)
    #   VAOS::V1::OperationOutcomeSerializer.new(operation_outcome).serialized_json
    class OperationOutcomeSerializer
      # Creates a new serializer instance
      # @param operation_outcome VAOS::V1::OperationOutcome an instance of a outcome model
      # @return VAOS::V1::OperationOutcomeSerializer the instance

      def initialize(operation_outcome)
        @operation_outcome = operation_outcome
      end

      # Creates a serializable hash in FHIR Operation Outcome format
      # @return Hash a hash ready for serialization
      def serializable_hash
        issue = serialize_issue(@operation_outcome.issue)
        {
          resourceType: @operation_outcome.resource_type,
          id: @operation_outcome.id,
          text: {
            status: 'generated',
            div: "<div xmlns=\"http://www.w3.org/1999/xhtml\"><p>#{issue.first[:details]}</p></div>"
          },
          issue:
        }
      end

      # Encodes a hash as JSON
      # @return String the JSON string
      def serialized_json
        ActiveSupport::JSON.encode(serializable_hash)
      end

      private

      def serialize_issue(issue)
        case issue
        when Common::Exceptions::BaseError
          serialize_base_error(issue)
        when StandardError
          serialize_standard_error(issue)
        else
          # it's unlikely we'll use informational outcomes (not an ok response nor an error)
          # but it's part of the FHIR spec to allow it
          serialize_information(issue)
        end
      end

      def serialize_base_error(issue)
        issue.errors.map do |error|
          {
            severity: 'error',
            code: error.code,
            details: {
              text: error.detail
            },
            diagnostics: error.source.is_a?(Class) ? error.source.to_s : error.source
          }
        end
      end

      def serialize_standard_error(issue)
        [{
          severity: 'error',
          code: '500',
          details: issue.message
        }]
      end

      def serialize_information(issue)
        [
          {
            severity: 'information',
            code: 'suppressed',
            details: {
              text: issue[:detail]
            }
          }
        ]
      end
    end
  end
end
