# frozen_string_literal: true
module Common
  module Exceptions
    # InvalidFieldValue - field value is invalid
    class InvalidFieldValue < BaseError
      attr_reader :field, :value

      def initialize(field, value)
        @field = field
        @value = value
      end

      def errors
        detail = "\"#{value}\" is not a valid value for \"#{field}\""
        Array(SerializableError.new(MinorCodes::INVALID_FIELD_VALUE.merge(detail: detail)))
      end
    end
  end
end
