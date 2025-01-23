# frozen_string_literal: true

module AskVAApi
  class TranslatorError < StandardError; end

  class Translator
    MAPPINGS = {
      'levelofauthentication' => 'level_of_authentication',
      'veteranrelationship' => 'veteran_relationship',
      'responsetype' => 'response_type',
      'dependentrelationship' => 'dependent_relationship',
      'inquiryabout' => 'inquiry_about'
    }.freeze

    EXACT_MATCH_KEYS = %i[veteran_relationship dependent_relationship].freeze

    def call(key, value)
      return if value.nil?

      optionset = fetch_optionset
      translated_value = translate_value(key, value)
      find_option_id(optionset, key, translated_value)
    end

    private

    # Translates the value based on key if translation is required
    def translate_value(key, value)
      EXACT_MATCH_KEYS.include?(key) ? I18n.t("ask_va_api.#{key}.#{value}") : value
    end

    # Finds the corresponding option ID in the optionset based on translated value
    def find_option_id(optionset, key, value)
      raise TranslatorError, "Key '#{key}' not found in optionset data" unless optionset[key]

      optionset[key].each do |obj|
        return obj[:Id] if exact_match?(key, obj[:Name], value) || normalized_match?(obj[:Name], value)
      end
      nil
    end

    # Checks for an exact match if the key requires it
    def exact_match?(key, name, value)
      EXACT_MATCH_KEYS.include?(key) && name == value
    end

    # Normalizes and matches inputs for non-exact match keys
    def normalized_match?(name, value)
      normalize_text(name) == normalize_text(value)
    end

    # Fetches and formats optionset data into a hash with snake_case keys
    def fetch_optionset
      retrieve_option_set[:Data].each_with_object({}) do |option, hash|
        key = convert_to_snake_case(option[:Name])
        hash[key.to_sym] = option[:ListOfOptions]
      end
    rescue => e
      raise TranslatorError, "Failed to retrieve optionset data: #{e.message}"
    end

    # Retrieves optionset data from cache
    def retrieve_option_set
      Crm::CacheData.new.call(endpoint: 'optionset', cache_key: 'optionset')
    end

    # Converts a string to snake_case and applies mappings if necessary
    def convert_to_snake_case(str)
      cleaned_str = str.gsub(/^iris_/, '').downcase
      MAPPINGS.fetch(cleaned_str, cleaned_str)
    end

    # Normalizes text by removing non-alphanumeric characters and downcasing
    def normalize_text(text)
      text.gsub(/[^a-z0-9]/i, '').downcase
    end
  end
end
