# frozen_string_literal: true
module Common
  module Exceptions
    # Routing Error - if route is invalid
    class RoutingError < BaseError
      def initialize(path = nil)
        detail = MinorCodes::ROUTING_ERROR[:detail]
        @detail = path.present? ? "#{detail}: #{path}" : detail
      end

      def errors
        Array(SerializableError.new(MinorCodes::ROUTING_ERROR.merge(detail: @detail)))
      end
    end
  end
end
