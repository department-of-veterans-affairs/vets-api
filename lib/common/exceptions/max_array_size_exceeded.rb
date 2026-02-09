# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    # MaxArraySizeExceeded - array exceeds the maximum allowed size
    class MaxArraySizeExceeded < BaseError
      attr_reader :field, :max_size, :actual_size

      def initialize(field, actual_size, max_size)
        super()
        @field = field
        @actual_size = actual_size
        @max_size = max_size
      end

      def errors
        Array(
          SerializableError.new(
            i18n_interpolated(
              detail: {
                field: @field,
                max_size: @max_size,
                actual_size: @actual_size
              }
            )
          )
        )
      end
    end
  end
end
