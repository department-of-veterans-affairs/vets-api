# frozen_string_literal: true

require_relative 'schema_error.rb'

module DecisionReview
  class ResponseSchemaError < SchemaError
    def response
      object
    end
  end
end
