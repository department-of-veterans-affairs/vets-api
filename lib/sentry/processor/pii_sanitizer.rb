# frozen_string_literal: true

module Sentry
  module Processor
    class PIISanitizer < Raven::Processor
      SANITIZED_FIELDS =
        %w[
          accountNumber
          accountType
          address_line1
          address_line2
          address_line3
          bankName
          birth_date
          city
          country
          dslogon_idvalue
          fileNumber
          firstName
          fname
          gender
          lastName
          lname
          mname
          phone
          postalCode
          routingNumber
          social
          ssn
          state
          street
          va_eauth_authorization
          va_eauth_birlsfilenumber
          va_eauth_gcIds
          vaEauthPnid
          zipCode
        ].freeze

      SANITIZER_EXCEPTIONS =
        %w[
          relaystate
        ].freeze

      PATTERN = Regexp.union(SANITIZED_FIELDS.map { |field| field.downcase.tr('_', '') }).freeze

      JSON_STARTS_WITH = ['[', '{'].freeze

      FILTER_MASK = 'FILTERED-CLIENTSIDE'
      FILTER_MASK_NIL = "#{FILTER_MASK}-NIL".freeze
      FILTER_MASK_BLANK = "#{FILTER_MASK}-BLANK".freeze

      def process(unsanitized_object)
        sanitize(unsanitized_object.deep_dup)
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
          if object.match(PATTERN) && (json = parse_json_or_nil(object))
            object = sanitize(json).to_json
          else
            object
          end
        else
          object
        end
      end

      def filter(key, unsanitized_value)
        if filter_pattern(key)
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

      def filter_pattern(key)
        normalized_key = key.to_s.tr('_', '').downcase
        normalized_key.match(PATTERN) && SANITIZER_EXCEPTIONS.exclude?(normalized_key)
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
