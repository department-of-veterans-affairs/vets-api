# frozen_string_literal: true

module PreferencesRedis
  class Response
    attr_reader :code, :choices

    def initialize(code)
      @code = code
      @choices = Preference.with_choices(code)
    end

    def self.for(code)
      new(code)
    end

    def cache?
      return if choices.blank?

      choices.dig(:preference_choices).present?
    end
  end
end
