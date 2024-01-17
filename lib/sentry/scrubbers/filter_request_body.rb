# frozen_string_literal: true

# only change from previous file was Processor was renamed to Scrubbers

module Sentry
  module Scrubbers
    class FilterRequestBody
      FILTERED_CONTROLLERS = %w[ppiu].freeze

      def new
        self
      end

      def process(data)
        sanitize(data.deep_stringify_keys)
      end

      private

      def sanitize(stringified_data)
        if FILTERED_CONTROLLERS.include?(stringified_data.dig('tags', 'controller_name')) &&
           stringified_data.dig('request', 'data').present?

          stringified_data['request']['data'] = PIISanitizer::FILTER_MASK
        end

        stringified_data
      end
    end
  end
end
