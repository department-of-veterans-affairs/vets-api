# frozen_string_literal: true

require 'singleton'

module Vet360
  class Exceptions
    include Singleton

    attr_reader :keys

    def initialize
      @keys = nil
    end

    def known_keys
      @keys = exception_keys
    end

    private

    # Parses our exceptions file and returns all of the Vet360 exception keys.
    #
    # @return [Array] An array of lowercased, alphabetized, Vet360 exception keys
    #
    def exception_keys
      exceptions_file
        .dig('en', 'common', 'exceptions')
        .keys
        .select { |exception| exception.include? 'VET360_' }
        .sort
        .map(&:downcase)
    end

    def exceptions_file
      config = Rails.root + 'config/locales/exceptions.en.yml'

      YAML.load_file(config)
    end
  end
end
