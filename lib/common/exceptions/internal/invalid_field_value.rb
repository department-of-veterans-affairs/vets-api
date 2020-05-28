# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions::Internal
    # InvalidFieldValue - field value is invalid
    class InvalidFieldValue < Common::Exceptions::BaseError
      attr_reader :field, :value

      def initialize(field, value)
        @field = field
        @value = value
      end

      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_interpolated(detail: { field: @field, value: @value })))
      end
    end
  end
end
