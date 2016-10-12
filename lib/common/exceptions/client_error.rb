# frozen_string_literal: true
module Common
  module Exceptions
    # ClientError - Generic Downstream errors returned from api
    class ClientError < BaseError
      attr_reader :resource

      def initialize(detail, options = {})
        @detail = detail
        @meta = options[:meta]
      end

      def errors
        Array(SerializableError.new(MinorCodes::CLIENT_ERROR.merge(detail: @detail, meta: @meta)))
      end
    end
  end
end
