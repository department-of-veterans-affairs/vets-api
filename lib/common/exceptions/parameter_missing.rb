# frozen_string_literal: true
module Common
  module Exceptions
    # Parameter Missing - required parameter was not provided
    class ParameterMissing < BaseError
      attr_reader :param

      def initialize(param, options = {})
        @param = param
        @detail = options[:detail]
      end

      def errors
        detail = @detail || "The required parameter \"#{param}\", is missing"
        Array(SerializableError.new(MinorCodes::PARAMETER_MISSING.merge(detail: detail)))
      end
    end
  end
end
