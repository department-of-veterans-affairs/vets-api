# frozen_string_literal: true
module Common
  module Exceptions
    # Unauthorized - We may eventually want different variations on this with distinct MinorCodes
    class Unauthorized < BaseError
      def initialize(options = {})
        @detail = options[:detail]
      end

      def errors
        detail = @detail || "Not Authorized"
        Array(SerializableError.new(MinorCodes::UNAUTHORIZED.merge(detail: detail)))
      end
    end
  end
end
