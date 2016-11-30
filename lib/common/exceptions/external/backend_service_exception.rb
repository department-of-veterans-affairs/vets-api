# frozen_string_literal: true
module Common
  module Exceptions
    # BackendServiceException - This will eventually receive a Common::Client::Errors:BackendServiceError
    # It should not be invoked directly by clients at any time. The Client:Error should be
    # rescued and this should be raised instead.
    class BackendServiceException < BaseError
      def initialize(error_klass = nil, options = {})
        @error_klass = error_klass || 'client_error'
        @detail = options[:detail]
        @source = options[:source]
        @meta = options[:meta] unless Rails.env.production?
      end

      def message
        i18n_data('title')
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(detail: @detail, source: @source, meta: @meta)))
      end

      private

      def i18n_key
        "common.exceptions.#{@error_klass}"
      end
    end
  end
end
