# frozen_string_literal: true
module Common
  module Exceptions
    # Routing Error - if route is invalid
    class RoutingError < BaseError
      def errors
        Array(SerializableError.new(MinorCodes::ROUTING_ERROR))
      end
    end
  end
end
