# frozen_string_literal: true

require 'simple_forms_api/engine'

module SimpleFormsApi
  module Exceptions
    class ScrubbedUploadsSubmitError < RuntimeError
      attr_reader :params

      def initialize(params)
        super
        @params = params
      end

      def message
        scrub_pii(super)
      end

      private

      def scrub_pii(message)
        words_to_remove = aggregate_words(JSON.parse(params.to_json))

        case params[:form_number]
        when '21-4142'
          return redact_words(message, SimpleFormsApi::VBA214142.new(params).key_values_to_remove)
        when '21-10210'
          words_to_remove += SimpleFormsApi::VBA2110210.new(params).words_to_remove
        when '26-4555'
          words_to_remove += SimpleFormsApi::VBA264555.new(params).words_to_remove
        when '21P-0847'
          words_to_remove += SimpleFormsApi::VBA21p0847.new(params).words_to_remove
        when '21-0845'
          words_to_remove += SimpleFormsApi::VBA210845.new(params).words_to_remove
        else
          return "something has gone wrong with your form, #{params[:form_number]} and the entire " \
                 'error message has been redacted to keep PII from getting leaked'
        end

        remove_words(message, words_to_remove)
      end

      def remove_words(message, words_to_remove)
        words_to_remove.compact.each do |word|
          message.gsub!(word, '')
          message.gsub!(word.upcase, '')
        end

        message
      end

      def redact_words(message, key_segments)
        # Extract the error message from the error string
        malformed_json = message.match(/unexpected token at '(.+?)'/)[1]

        # RegEx to match key-value pairs
        key_value_regex = /"([^"]+)":\s*"([^"]*)"/

        # Iterate over key-value pairs and replace values of keys containing specified substrings
        redacted_json = malformed_json.gsub(key_value_regex) do |match|
          key = $1
          value = $2
          if key_segments.any? { |segment| key.include?(segment) }
            %("#{key}": "<REDACTED>")
          else
            match
          end
        end

        "An unexpected token was found while parsing the payload: #{redacted_json}"
      end

      def aggregate_words(parsed_params)
        words = []
        parsed_params.each_value do |value|
          case value
          when Hash
            words += aggregate_words(value)
          when String
            words += value.split
          end
        end

        words.uniq.sort_by(&:length).reverse
      end
    end
  end
end
