# frozen_string_literal: true

require_relative 'request_schema_error'

module DecisionReview
  class Request
    attr_reader :data

    def initialize(data)
      @data = data
      raise RequestSchemaError.new(self) unless schema_errors.empty?
    end

    def schema_errors
      raise NotImplementedError, 'Subclass of Request must implement schema_errors method'
    end

    def perform_args
      raise NotImplementedError, 'Subclass of Request must implement perform_args method'
    end
  end
end
