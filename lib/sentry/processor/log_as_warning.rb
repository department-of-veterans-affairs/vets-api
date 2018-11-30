# frozen_string_literal: true

module Sentry
  module Processor
    class LogAsWarning < Raven::Processor
      SENTRY_LOG_LEVEL_WARNING = 30

      def process(data)
        process_if_symbol_keys(data) if data[:exception]
        process_if_string_keys(data) if data['exception']
        data
      end

      private

      def process_if_symbol_keys(data)
        if data[:exception][:values].last[:type] == Common::Exceptions::GatewayTimeout.to_s
          data[:level] = SENTRY_LOG_LEVEL_WARNING
        end
      end

      def process_if_string_keys(data)
        if data['exception']['values'].last['type'] == Common::Exceptions::GatewayTimeout.to_s
          data['level'] = SENTRY_LOG_LEVEL_WARNING
        end
      end
    end
  end
end
