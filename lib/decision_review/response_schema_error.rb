# frozen_string_literal: true

module DecisionReview
  class ResponseSchemaError < SchemaError
    def response
      object
    end
  end
end
