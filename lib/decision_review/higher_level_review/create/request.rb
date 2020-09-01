# frozen_string_literal: true

require 'json_schemer'
require 'vets_json_schema'
require_relative '../../request.rb'

module DecisionReview
  module HigherLevelReview
    module Create
      class Request < DecisionReview::Request
        HEADERS_VALIDATOR = JSONSchemer.schema(VetsJsonSchema::SCHEMAS['HLR-CREATE-REQUEST-HEADERS'])
        raise unless HEADERS_VALIDATOR
        BODY_VALIDATOR = JSONSchemer.schema(VetsJsonSchema::SCHEMAS['HLR-CREATE-REQUEST-BODY'])
        raise unless BODY_VALIDATOR

        def perform_args
          [:post, 'higher_level_reviews', data.body, data.headers]
        end

        def schema_errors
          @schema_errors ||= header_errors + body_errors
        end

        private

        def header_errors
          HEADERS_VALIDATOR.validate(data.headers).to_a
        end

        def body_errors
          BODY_VALIDATOR.validate(data.body).to_a
        end
      end
    end
  end
end
