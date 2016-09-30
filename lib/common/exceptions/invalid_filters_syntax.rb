# frozen_string_literal: true
module Common
  module Exceptions
    # InvalidFiltersSyntax - filter keys are invalid
    class InvalidFiltersSyntax < BaseError
      attr_reader :filters

      def initialize(filters, options = {})
        @filters = filters
        @detail = options[:detail]
      end

      def errors
        detail = @detail || "#{filters} is not a valid syntax for filtering"
        Array(SerializableError.new(MinorCodes::INVALID_FILTERS_SYNTAX.merge(detail: detail)))
      end
    end
  end
end
