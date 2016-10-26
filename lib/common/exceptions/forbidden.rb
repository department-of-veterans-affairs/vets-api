# frozen_string_literal: true
module Common
  module Exceptions
    # Forbidden - We may eventually want different variations on this with distinct MinorCodes
    class Forbidden < BaseError
      def initialize(options = {})
        @detail = options[:detail]
      end

      def errors
        detail = @detail || 'Forbidden'
        Array(SerializableError.new(MinorCodes::FORBIDDEN.merge(detail: detail)))
      end
    end
  end
end
