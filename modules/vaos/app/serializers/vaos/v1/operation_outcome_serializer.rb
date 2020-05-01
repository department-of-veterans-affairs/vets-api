# frozen_string_literal: true

module VAOS
  module V1
    # http://hl7.org/fhir/DSTU2/operationoutcome.html
    class OperationOutcomeSerializer
      def initialize(operation_outcome)
        @operation_outcome = operation_outcome
      end

      def serializable_hash
        {
          resourceType: @operation_outcome.resource_type,
          issue: serialize_issue(@operation_outcome.issue)
        }
      end

      def serialized_json
        ActiveSupport::JSON.encode(serializable_hash)
      end

      private

      def serialize_issue(issue)
        case issue
        when Common::Exceptions::BaseError
          issue.errors.map do |error|
            {
              severity: 'error',
              code: error.code,
              details: error.detail,
              diagnostics: error.source
            }
          end
        when StandardError
          [{
            severity: 'error',
            code: '500',
            details: issue.message
          }]
        else
          [
            {
              severity: 'information',
              code: 'suppressed',
              details: issue
            }
          ]
        end
      end
    end
  end
end

