# frozen_string_literal: true
module Common
  module Exceptions
    # Routing Error - if route is invalid
    class MethodNotAllowed < BaseError
      attr_accessor :allowed_methods

      def initialize(allowed_methods, method = nil, path = nil)
        @allowed_methods = allowed_methods
        detail = MinorCodes::METHOD_NOT_ALLOWED[:detail]
        @detail = method.present? && path.present? ? "#{method} #{detail}: #{path}" : detail
      end

      def errors
        Array(SerializableError.new(MinorCodes::METHOD_NOT_ALLOWED.merge(detail: @detail)))
      end
    end
  end
end
