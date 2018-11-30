# frozen_string_literal: true

module Sentry
  module Processor
    class LogAsWarning < Raven::Processor
      def process(data)
        process_if_symbol_keys(data) if data[:exception]
        process_if_string_keys(data) if data['exception']
        data
      end

      private

      def process_if_symbol_keys(data)
        data[:level] = 30 if data[:exception][:values].last[:type] == 'Common::Exceptions::GatewayTimeout'
      end

      def process_if_string_keys(data)
        data['level'] = 30 if data['exception']['values'].last['type'] == 'Common::Exceptions::GatewayTimeout'
      end
    end
  end
end
