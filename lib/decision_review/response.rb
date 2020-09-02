# frozen_string_literal: true

require 'json_schemer'
require 'vets_json_schema'
require_relative 'response_schema_error.rb'

module DecisionReview
  class Response < SimpleDelegator
    def initialize(response_object)
      super
      raise ResponseSchemaError.new(self) unless schema_errors.empty?
    end

    def schema_errors
      @schema_errors ||= validator ? validator.validate(body).to_a : [unrecognized_response]
    end

    private

    def validator
      @validator ||= validators_by_status[status]
    end

    def validators_by_status
      @validators_by_status ||= VetsJsonSchema::SCHEMAS.reduce({}) do |acc, (key, schema)|
        match = key.match(self.class::SCHEMA_REGEX)
        next acc unless match

        status = match[1].to_i
        acc.merge status => JSONSchemer.schema(schema)
      end
    end

    def unrecognized_response
      {
        code: :unrecognized_response,
        title: 'Unrecognized response by upstream API',
        status: status,
        body: body
      }
    end
  end
end
