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

    def call(key, value)
      return if value.nil?

      optionset = fetch_optionset

      if optionset[key]
        match = optionset[key].find { |obj| value.downcase.include?(obj[:Name].downcase) }
        match[:Id] if match
      else
        raise TranslatorError, "Key '#{key}' not found in optionset data"
      end
    end

    private

    def fetch_optionset
      retrieve_option_set[:Data].each_with_object({}) do |option, hash|
        hash[to_snake_case(option[:Name]).to_sym] = option[:ListOfOptions]
      end
    rescue => e
      raise TranslatorError, "Failed to retrieve optionset data: #{e.message}"
    end

    def retrieve_option_set
      Crm::CacheData.new.call(endpoint: 'optionset', cache_key: 'optionset')
    end

    def to_snake_case(str)
      data = str.gsub(/^iris_/, '').downcase
      MAPPINGS.fetch(data.downcase, data)
    end
  end
end
