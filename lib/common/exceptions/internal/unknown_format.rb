# frozen_string_literal: true

module Common
  module Exceptions
    # Routing Error - if route is invalid
    class UnknownFormat < BaseError
      attr_reader :format

      def initialize(format = nil)
        @format = format
      end

      def errors
        Array(SerializableError.new(i18n_interpolated(detail: { format: @format })))
      end
    end
  end
end
