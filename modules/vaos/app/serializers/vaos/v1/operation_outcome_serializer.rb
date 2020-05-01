# frozen_string_literal: true

module VAOS
  module V1
    # http://hl7.org/fhir/DSTU2/operationoutcome.html
    class OperationOutcomeSerializer
      def initialize(operation_outcome)
        @operation_outcome = operation_outcome
      end

      def serializable_hash
        issue = serialize_issue(@operation_outcome.issue)
        {
          resourceType: @operation_outcome.resource_type,
          id: @operation_outcome.id,
          text: {
            status: 'generated',
            div: "<div xmlns=\"http://www.w3.org/1999/xhtml\"><p>#{issue.first[:details]}</p></div>"
          },
          issue: issue
        }
      end

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
            details: error.detail,
            diagnostics: error.source
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
            details: issue[:detail]
          }
        ]
      end
    end
  end
end
