# frozen_string_literal: true

module Sentry
  module Processor
    class PIISanitizer < Raven::Processor
      SANITIZED_FIELDS = %w[ city country gender phone postalCode zipCode fileNumber state street vaEauthPnid
                             vaEauthBirthdate accountType accountNumber routingNumber bankName ssn birth_date
                             social fname lname mname dslogon_idvalue ].uniq.freeze

      JSON_STARTS_WITH = ['[', '{'].freeze

      FILTER_MASK = 'FILTERED-CLIENTSIDE'
      FILTER_MASK_NIL = FILTER_MASK + '-NIL'
      FILTER_MASK_BLANK = FILTER_MASK + '-BLANK'

      def process(unsanitized_object)
        object = unsanitized_object.dup
        sanitize(object)
      end

      private

      def sanitize(object)
        case object
        when Hash
          object.each do |k, v|
            object[k] = filter(k, sanitize(v))
          end
        when Array
          object.each_with_index do |value, index|
            object[index] = sanitize(value)
          end
        when String
          if object.match(pattern) && (json = parse_json_or_nil(object))
            object = sanitize(json).to_json
          else
            object
          end
        else
          object
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      def pattern
        @pattern ||= Regexp.union(SANITIZED_FIELDS.map { |field| field.tr('_', '').downcase })
      end

      def filter(key, unsanitized_value)
        if key.to_s.tr('_', '').downcase.match(pattern)
          if unsanitized_value.is_a?(Array)
            unsanitized_value.map { |element| filter(key, element) }
          else
            return FILTER_MASK_NIL if unsanitized_value.nil?
            return FILTER_MASK_BLANK if unsanitized_value.blank?
            FILTER_MASK
          end
        else
          unsanitized_value
        end
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
