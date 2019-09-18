# frozen_string_literal: true

module Sentry
  module Processor
    class FilterRequestBody < Raven::Processor
      FILTERED_CONTROLLERS = %w[ppiu].freeze

      def process(data)
        stringified_data = data.deep_stringify_keys

        if FILTERED_CONTROLLERS.include?(stringified_data.dig('tags', 'controller_name')) &&
           stringified_data.dig('request', 'data').present?

          stringified_data['request']['data'] = PIISanitizer::FILTER_MASK
        end

        stringified_data
      end

      private

      def sanitize
      end
    end
  end
end
