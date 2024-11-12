# frozen_string_literal: true

require 'ivc_champva/engine'
require 'securerandom'

module IvcChampva
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
        when '10-7959F-1'
          words_to_remove += IvcChampva::VHA107959f1.new(params).words_to_remove
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
