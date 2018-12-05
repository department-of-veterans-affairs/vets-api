# frozen_string_literal: true

module Sentry
  module Processor
    class LogAsWarning < Raven::Processor
      SENTRY_LOG_LEVEL_WARNING = 30
      RELEVANT_EXCEPTIONS = [
        Common::Exceptions::GatewayTimeout.to_s,
        EVSS::ErrorMiddleware::EVSSError.to_s
      ]

      def process(data)
        process_if_symbol_keys(data) if data[:exception]
        process_if_string_keys(data) if data['exception']
        data
      end

      private

      def process_if_symbol_keys(data)
        if RELEVANT_EXCEPTIONS.include?(data[:exception][:values].last[:type])
          data[:level] = SENTRY_LOG_LEVEL_WARNING
        end
      end

      def process_if_string_keys(data)
        if RELEVANT_EXCEPTIONS.include?(data['exception']['values'].last['type'])
          data['level'] = SENTRY_LOG_LEVEL_WARNING
        end
      end
    end
  end
end
