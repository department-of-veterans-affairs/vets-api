# frozen_string_literal: true

module Common
  module Exceptions
    # Routing Error - if route is invalid
    class RoutingError < BaseError
      attr_reader :path

      def initialize(path = nil)
        @path = path
      end

      def errors
        Array(SerializableError.new(i18n_interpolated(detail: { path: @path })))
      end
    end
  end
end
