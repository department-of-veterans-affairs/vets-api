# frozen_string_literal: true

module DecisionReview
  class RequestSchemaError < SchemaError
    def request
      object
    end
  end
end
