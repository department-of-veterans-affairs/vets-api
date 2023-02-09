# frozen_string_literal: true

module ClaimsApi
  module LocalBGS
    module StringUtils
      # almost ActiveSupport's camelize
      # --doesn't convert '/' to '::', and doesn't use inflectors
      def self.camelize(string, mode = DEFAULT_CAMELIZE_MODE)
        snake_case_converter(string, '', CAMELIZE_MODE_TO_PROC.send(mode), &:capitalize)
      end

      def self.camelcase(string, mode = DEFAULT_CAMELIZE_MODE)
        camelize string, mode
      end

      def self.to_bgs_key(string, mode = DEFAULT_CAMELIZE_MODE)
        camelize_but_use_ID_for_id string, mode
      end

      def self.camelize_but_use_ID_for_id(string, mode = DEFAULT_CAMELIZE_MODE) # rubocop:disable Naming/MethodName
        snake_case_converter(string, '', proc { |w| to_ID(w) || CAMELIZE_MODE_TO_PROC.send(mode).call(w) }) do |w|
          to_ID(w) || w.capitalize
        end
      end

      def self.snake_case_converter(
        snake_case_string,
        join_with = '_',
        converter_for_the_first_word = nil,
        &converter
      )
        converter ||= IDENTITY_FUNCTION
        converter_for_the_first_word ||= converter

        words = snake_case_string.to_s.split('_')

        return '' if words.empty?

        [
          converter_for_the_first_word.call(words.first),
          *words[1..].map(&converter)
        ].join(join_with)
      end

      private_class_method def self.to_ID(string) # rubocop:disable Naming/MethodName
        /id/i === string && 'ID' # rubocop:disable Style/CaseEquality
      end

      IDENTITY_FUNCTION = proc { |x| x }
      private_constant :IDENTITY_FUNCTION

      UPCASE_FIRST_CHARACTER = proc { |string| "#{string[0]&.upcase}#{string[1..]}" }
      private_constant :UPCASE_FIRST_CHARACTER

      DOWNCASE_FIRST_CHARACTER = proc { |string| "#{string[0]&.downcase}#{string[1..]}" }
      private_constant :DOWNCASE_FIRST_CHARACTER

      CAMELIZE_MODE_TO_PROC = Object.new
      CAMELIZE_MODE_TO_PROC.define_singleton_method(:upper) { UPCASE_FIRST_CHARACTER }
      CAMELIZE_MODE_TO_PROC.define_singleton_method(:lower) { DOWNCASE_FIRST_CHARACTER }
      private_constant :CAMELIZE_MODE_TO_PROC

      DEFAULT_CAMELIZE_MODE = :upper
    end
  end
end
