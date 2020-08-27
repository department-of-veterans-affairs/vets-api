# frozen_string_literal: true

module DecisionReview
  class SchemaError < StandardError
    attr_reader :object

    def initialize(object)
      @object = object
    end

    def errors
      object.schema_errors
    end
  end
end
