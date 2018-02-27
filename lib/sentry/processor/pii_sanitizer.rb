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

      def process(value, key = nil)
        case value
        when Hash
          !value.frozen? ? value.merge!(value) { |k, v| process v, k } : value.merge(value) { |k, v| process v, k }
        else
          SANITIZED_FIELDS.include?(key.to_s.camelize(:lower)) ? 'FILTERED' : value
        end
      end
    end
  end
end
