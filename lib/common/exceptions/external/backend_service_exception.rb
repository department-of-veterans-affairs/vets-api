# frozen_string_literal: true
module Common
  module Exceptions
    # BackendServiceException - This will return a generic error, to customize
    # you must define the minor code in the locales file.
    class BackendServiceException < BaseError
      def initialize(i18n_key = nil, response_values = {})
        @response_values = response_values
        @i18n_key = i18n_key
      end

      def message
        "BackendServiceException: #{@response_values}"
      end

      def errors
        Array(SerializableError.new(i18n_data))
      end

      private

      def i18n_key
        @i18n_key || 'common.exceptions.backend_service_exception'
      end
    end
  end
end
