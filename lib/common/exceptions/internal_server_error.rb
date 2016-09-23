# frozen_string_literal: true
module Common
  module Exceptions
    # Internal Server Error - all exceptions not readily accounted fall into this tier
    class InternalServerError < BaseError
      attr_reader :exception

      def initialize(exception)
        raise ArgumentError, 'an exception must be provided' unless exception.is_a?(Exception)
        @exception = exception
      end

      def errors
        meta = { exception: exception.message, backtrace: exception.backtrace } unless ::Rails.env.production?
        Array(SerializableError.new(MinorCodes::INTERNAL_SERVER_ERROR.merge(meta: meta)))
      end
    end
  end
end
