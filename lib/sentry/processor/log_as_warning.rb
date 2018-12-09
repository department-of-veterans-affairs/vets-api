# frozen_string_literal: true

module Sentry
  module Processor
    class LogAsWarning < Raven::Processor
      SENTRY_LOG_LEVEL_WARNING = 30
      RELEVANT_EXCEPTIONS = [
        Common::Exceptions::GatewayTimeout,
        EVSS::ErrorMiddleware::EVSSError
      ].freeze

      def process(data)
        exception_class = get_exception_class(data)

        RELEVANT_EXCEPTIONS.each do |relevant_exception|
          if exception_class == relevant_exception || exception_class < relevant_exception
            data[:level] = SENTRY_LOG_LEVEL_WARNING
            break
          end
        end

        data
      end

      private

      def get_exception_class(data)
        if data[:exception]
          data[:exception][:values].last[:type]
        elsif data['exception']
          data['exception']['values'].last['type']
        end.constantize
      end
    end
  end
end
