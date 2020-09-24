# frozen_string_literal: true

require 'common/exceptions'
require 'evss/error_middleware'
require 'evss/disability_compensation_form/gateway_timeout'

module Sentry
  module Processor
    class LogAsWarning < Raven::Processor
      SENTRY_LOG_LEVEL_WARNING = 30
      RELEVANT_EXCEPTIONS = [
        Common::Exceptions::GatewayTimeout,
        EVSS::ErrorMiddleware::EVSSError
      ].freeze

      def process(data)
        stringified_data = data.deep_stringify_keys
        return stringified_data if stringified_data['exception'].blank?
        return set_warning_level(stringified_data) if stringified_data['extra'].try(:[], 'log_as_warning')

        exception_class = get_exception_class(stringified_data)

        RELEVANT_EXCEPTIONS.each do |relevant_exception|
          return set_warning_level(stringified_data) if exception_class <= relevant_exception
        end

        stringified_data
      end

      private

      def set_warning_level(data)
        data['level'] = SENTRY_LOG_LEVEL_WARNING

        data
      end

      def get_exception_class(data)
        data['exception']['values'].last['type'].constantize
      end
    end
  end
end
