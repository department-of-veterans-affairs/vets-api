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
        Array(SerializableError.new(i18n_interpolated(detail: { field: @field, value: @value })))
      end
    end
  end
end
