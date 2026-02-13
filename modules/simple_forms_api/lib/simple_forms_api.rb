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

      # rubocop:disable Metrics/MethodLength
      def scrub_pii(message)
        words_to_remove = aggregate_words(JSON.parse(params.to_json))

        case params[:form_number]
        when '21-4140'
          words_to_remove += SimpleFormsApi::VBA214140.new(params).words_to_remove
        when '21-4142'
          words_to_remove += SimpleFormsApi::VBA214142.new(params).words_to_remove
        when '21-10210'
          words_to_remove += SimpleFormsApi::VBA2110210.new(params).words_to_remove
        when '26-4555'
          words_to_remove += SimpleFormsApi::VBA264555.new(params).words_to_remove
        when '21P-0847'
          words_to_remove += SimpleFormsApi::VBA21p0847.new(params).words_to_remove
        when '21-0845'
          words_to_remove += SimpleFormsApi::VBA210845.new(params).words_to_remove
        when '40-0247'
          words_to_remove += SimpleFormsApi::VBA400247.new(params).words_to_remove
        when '21-0966'
          words_to_remove += SimpleFormsApi::VBA210966.new(params).words_to_remove
        when '20-10207'
          words_to_remove += SimpleFormsApi::VBA2010207.new(params).words_to_remove
        when '20-10206'
          words_to_remove += SimpleFormsApi::VBA2010206.new(params).words_to_remove
        when '40-10007'
          words_to_remove += SimpleFormsApi::VBA4010007.new(params).words_to_remove
        when '40-1330M'
          words_to_remove += SimpleFormsApi::VBA401330m.new(params).words_to_remove
        when '21P-601'
          words_to_remove += SimpleFormsApi::VBA21p601.new(params).words_to_remove
        when '21P-0537'
          words_to_remove += SimpleFormsApi::VBA21p0537.new(params).words_to_remove
        else
          return "something has gone wrong with your form, #{params[:form_number]} and the entire " \
                 'error message has been redacted to keep PII from getting leaked'
        end

        remove_words(message, words_to_remove)
      end
      # rubocop:enable Metrics/MethodLength

      def remove_words(message, words_to_remove)
        message = message.dup if Flipper.enabled?(:unfreeze_strings)
        words_to_remove.compact.each do |word|
          message.gsub!(word, '')
          message.gsub!(word.upcase, '')
        end

        message
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

    class BenefitsClaimsApiDownError < RuntimeError; end
  end
end
