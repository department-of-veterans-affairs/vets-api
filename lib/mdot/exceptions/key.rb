# frozen_string_literal: true

module MDOT
  class ExceptionKey
    attr_reader :key, :i18n_key

    def initialize(key)
      @default_exception = 'default_exception'
      @key = validate_key(key)
      @i18n_key = "mdot.exceptions.#{@key}"
    end

    private

    def key_exists?(key)
      I18n.exists?("mdot.exceptions.#{key}")
    end

    def validate_key(key)
      key.present? && key_exists?(key) ? key : @default_exception
    end
  end
end
