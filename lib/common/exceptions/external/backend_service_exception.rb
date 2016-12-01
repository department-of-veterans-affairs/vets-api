# frozen_string_literal: true
module Common
  module Exceptions
    # BackendServiceException - This will return a generic error, to customize
    # you must define the minor code in the locales file and call this class from
    # raise_error middleware.
    class BackendServiceException < BaseError
      attr_reader :response_values

      def initialize(key = nil, response_values = {})
        if response_values[:status]&.between?(400, 999)
          @response_values = response_values
        else
          raise NotImplementedError, 'only invoke from raise_error middleware'
        end
        @key = key || 'backend_service_exception'
      end

      def message
        "BackendServiceException: #{response_values}"
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(status: _status, detail: _detail, source: _source)))
      end

      private

      # The http status code. This is very important and required for rendering
      # unless you've specified that you want the status code to be something other
      # then 400 explicitly it will default to 400. IT WILL NOT DEFAULT to whatever
      # was provided by the backend service, because the backend service response
      # might not always be rele
      def _status
        i18n_data[:detail].presence || 400
      end

      # Default detail should be based on i18n but fallback if it is explicitly set to nil
      def _detail
        i18n_data[:detail].presence || response_values[:detail]
      end

      # This should usually be a developer message of some sort from the backend service
      def _source
        response_values[:source]
      end

      def i18n_key
        "common.exceptions.#{@key}"
      end
    end
  end
end
