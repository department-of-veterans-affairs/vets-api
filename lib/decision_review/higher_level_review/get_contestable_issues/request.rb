# frozen_string_literal: true

require 'json_schemer'
require 'vets_json_schema'
require_relative '../../request.rb'

module DecisionReview
  module HigherLevelReview
    module GetContestableIssues
      class Request < DecisionReview::Request
        HEADERS_VALIDATOR = JSONSchemer.schema(VetsJsonSchema::SCHEMAS['HLR-GET-CONTESTABLE-ISSUES-REQUEST-HEADERS'])
        BENEFIT_TYPE_VALIDATOR = JSONSchemer.schema(VetsJsonSchema::SCHEMAS['HLR-GET-CONTESTABLE-ISSUES-REQUEST-BENEFIT-TYPE'])

        def perform_args
          [:get, "higher_level_reviews/contestable_issues/#{data.benefit_type}", nil, data.headers]
        end

        def schema_errors
          [*header_errors, *benefit_type_errors]
        end

        private

        def header_errors
          @header_errors ||= HEADERS_VALIDATOR.validate(data.headers).to_a
        end

        def benefit_type_errors
          @benefit_type_errors ||= BENEFIT_TYPE_VALIDATOR.validate(data.benefit_type).to_a
        end
      end
    end
  end
end
