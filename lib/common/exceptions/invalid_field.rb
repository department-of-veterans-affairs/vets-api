# frozen_string_literal: true
module Common
  module Exceptions
    # InvalidField - field is invalid
    class InvalidField < BaseError
      attr_reader :field, :type

      def initialize(field, type)
        @field = field
        @type = type
      end

      def errors
        detail = "\"#{field}\" is not a valid field for \"#{type}\""
        Array(SerializableError.new(MinorCodes::INVALID_FIELD.merge(detail: detail)))
      end
    end
  end
end
