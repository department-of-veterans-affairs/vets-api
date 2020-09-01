# frozen_string_literal: true

require_relative 'schema_error.rb'

module DecisionReview
  class RequestSchemaError < SchemaError
    def request
      object
    end
  end
end
