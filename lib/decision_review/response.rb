# frozen_string_literal: true

module DecisionReview
  class Response < SimpleDelegator
    VALIDATORS_BY_STATUS = VetsJsonSchema::SCHEMAS.reduce({}) do |acc, (key, schema)|
      match = key.match(SCHEMA_REGEX)
      next acc unless match

      status = match[1]
      acc.merge status => JSONSchemer.schema(schema)
    end

    def initialize(response_object)
      super
      raise ResponseSchemaError.new(self) unless schema_errors.empty?
    end

    def schema_errors
      @schema_errors ||= validator ? validator.validate(body).to_a : [unrecognized_response]
    end

    private

    def validator
      @validator ||= VALIDATORS_BY_STATUS[response.status]
    end

    def unrecognized_response
      {
        code: :unrecognized_response,
        title: 'Unrecognized response by upstream API'
        status: status,
        body: body
      }
    end
  end
end
