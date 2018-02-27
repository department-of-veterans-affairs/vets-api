# frozen_string_literal: true

module Sentry
  module Processor
    class PIISanitizer < Raven::Processor
      SANITIZED_FIELDS = %w[
        city
        country
        gender
        phone
        postalCode
        state
        street
      ].freeze

      JSON_STARTS_WITH = ['[', '{'].freeze

      def process(value, key = nil)
        case value
        when Hash
          !value.frozen? ? value.merge!(value) { |k, v| process v, k } : value.merge(value) { |k, v| process v, k }
        when String
          # if this string is actually a json obj, convert and sanitize
          # taken from: https://github.com/getsentry/raven-ruby/blob/master/lib/raven/processor/sanitizedata.rb#L29
          if SANITIZED_FIELDS.any? { |field| value.include?(field) } && (json = parse_json_or_nil(value))
            process(json).to_json
          else
            filter_values(key, value)
          end
        else
          filter_values(key, value)
        end
      end

      private

      def filter_values(key, value)
        SANITIZED_FIELDS.include?(key.to_s.camelize(:lower)) ? 'FILTERED' : value
      end

      def parse_json_or_nil(string)
        return unless string.start_with?(*JSON_STARTS_WITH)
        JSON.parse(string)
      rescue JSON::ParserError, NoMethodError
        nil
      end
    end
  end
end
