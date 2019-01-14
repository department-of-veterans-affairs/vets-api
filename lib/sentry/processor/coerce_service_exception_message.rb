# frozen_string_literal: true

module Sentry
  module Processor
    class CoerceServiceExceptionMessage < Raven::Processor
      RELEVANT_EXCEPTIONS = [
        Common::Exceptions::BackendServiceException.to_s
      ].freeze

      def process(data)
        process_if_symbol_keys(data) if data[:exception]
        process_if_string_keys(data) if data['exception']
        data
      end

      private

      def process_if_symbol_keys(data)
        if RELEVANT_EXCEPTIONS.include?(data[:exception][:values].last[:type])
          data[:message] += ' msg'
        end
      end

      def process_if_string_keys(data)
        if RELEVANT_EXCEPTIONS.include?(data['exception']['values'].last['type'])
          data['message'] += ' msg'
        end
      end
    end
  end
end
