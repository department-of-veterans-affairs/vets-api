# frozen_string_literal: true

module DecisionReview
  module HigherLevelReview
    module GetContestableIssues
      class Request < DecisionReview::Request
        HEADERS_VALIDATOR = JSONSchemer.schema(VetsJsonSchema::SCHEMAS['HLR_GET_CONTESTABLE_ISSUES_HEADERS'])
        BENEFIT_TYPES = VetsJsonSchema::SCHEMAS.dig(*%w[20-0996 definitions hlrCreateBenefitType enum])
        raise unless BENEFIT_TYPES.is_a Array?

        def perform_args
          [:get, 'contestable_issues', nil, data.headers]
        end

        def schema_errors
          benefit_type_is_valid? ? headers_errors : [*header_errors, benefit_type_error]
        end

        private

        def header_errors
          @header_errors ||= HEADERS_VALIDATOR.validate(data.headers).to_a
        end

        def benefit_type_is_valid?
          data.benefit_type.in? BENEFIT_TYPES
        end

        def benefit_type_error
          {
            code: 'invalid_benefit_type',
            title: 'Invalid benefit type.',
            detail: "Invalid benefit type: #{data.benefit_type.inspect}. Valid benefit types: #{BENEFIT_TYPES}"
          }
        end
      end
    end
  end
end
