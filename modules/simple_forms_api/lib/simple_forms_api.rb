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
          words_to_remove += SimpleFormsApi::VBA214142.new(params).words_to_remove
        when '21-10210'
          words_to_remove += SimpleFormsApi::VBA2110210.new(params).words_to_remove
        end

        words_to_remove.compact.each do |word|
          message.gsub!(word, '')
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
  end
end
