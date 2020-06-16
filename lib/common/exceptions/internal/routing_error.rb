# frozen_string_literal: true

module Common
  module Exceptions::Internal
    # Routing Error - if route is invalid
    class RoutingError < Common::Exceptions::BaseError
      attr_reader :path

      def initialize(path = nil)
        @path = path
      end

      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_interpolated(detail: { path: @path })))
      end
    end
  end
end
