# frozen_string_literal: true

require 'singleton'

module VAProfile
  module Exceptions
    # This class parses all of the VAProfile exception keys from config/locales/exceptions.en.yml
    # and saves them to an instance variable.  For performance reasons, the Singleton Pattern
    # is used.  This allows the file system to be hit one time, when a server instance is
    # initialized.  From that point forward, the exception keys are saved to an instance
    # variable in this class, thereby eliminating the need for the file system to be hit repeatedly.
    #
    class Parser
      include Singleton

      # Parses our exceptions file and returns all of the VAProfile exception keys.  Memoizes this
      # value by setting it equal to the @keys instance variable.
      #
      # @return [Array] An array of lowercased, alphabetized, VAProfile exception keys
      #
      def known_keys
        @keys ||= exception_keys
      end

      # Checks if the passed exception key is present in the exceptions_file
      #
      # @param exception_key [String] A VAProfile exception key from config/locales/exceptions.en.yml
      #   For example, 'VET360_ADDR133'
      # @return [Boolean]
      #
      def known?(exception_key)
        known_keys.include? exception_key.downcase
      end

      def known_exceptions
        exceptions_file
          .dig('en', 'common', 'exceptions')
          .select { |key, _| key.include? 'VET360_' }
      end

      private

      def exception_keys
        known_exceptions
          .keys
          .sort
          .map(&:downcase)
      end

      def exceptions_file
        config = Rails.root.join('config', 'locales', 'exceptions.en.yml')

        YAML.load_file(config, aliases: true)
      end
    end
  end
end
