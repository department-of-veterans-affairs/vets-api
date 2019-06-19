# frozen_string_literal: true

require 'sentry_logging'
module Common
  module Exceptions
    # This will return a generic error, to customize
    # you must define the minor code in the locales file and call this class from
    # raise_error middleware.
    class BingServiceError < BaseError
      attr_reader :response_values, :original_status, :original_body, :key

      def initialize(error_messages)
        @error_messages = { detail: error_messages }
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(@error_messages)))
      end

      def status_code
        500
      end
    end
  end
end
