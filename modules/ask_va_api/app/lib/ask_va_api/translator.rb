# frozen_string_literal: true

module AskVAApi
  class TranslatorError < StandardError; end

  class Translator
    attr_reader :inquiry_params, :optionset_entity_class, :retriever, :logger

    def initialize(inquiry_params:, entity_class: Optionset::Entity)
      @inquiry_params = inquiry_params
      @translation_cache = {}
      @optionset_entity_class = entity_class
      @retriever = Optionset::Retriever
      @logger = LogService.new
    end

    def call
      payload = convert_keys_to_camel_case(inquiry_params, fetch_translation_map('inquiry'))

      options.each do |option|
        update_option_in_payload(payload, option)
      end

      payload
    end

    private

    def convert_keys_to_camel_case(params, translation_map)
      params.each_with_object({}) do |(key, value), result|
        camel_case_key = translation_map[key.to_sym]

        result[camel_case_key.to_sym] = case value
                                        when Hash
                                          convert_keys_to_camel_case(value, fetch_translation_map(key))
                                        when Array
                                          value.map { |v| convert_keys_to_camel_case(v, fetch_translation_map(key)) }
                                        else
                                          value
                                        end
      end
    end

    def update_option_in_payload(payload, option)
      option_set = retrieve_option_set(option)
      option_key = options_converter_hash[option]

      return unless option_key

      matching_option = option_set.find { |obj| obj.name == payload[option_key] }
      payload[option_key] = matching_option.id if matching_option
    rescue => e
      log_error("update option #{option}", e)
      raise TranslatorError, e if e.message.include?('Crm::CacheDataError')
    end

    def retrieve_option_set(option)
      retriever.new(name: option, user_mock_data: nil, entity_class: optionset_entity_class).call
    end

    def options
      @options ||= %w[
        inquiryabout inquirysource inquirytype levelofauthentication
        suffix veteranrelationship dependentrelationship responsetype
      ]
    end

    def options_converter_hash
      {
        'inquiryabout' => :InquiryAbout,
        'inquirysource' => :InquirySource,
        'inquirytype' => :InquiryType,
        'levelofauthentication' => :LevelOfAuthentication,
        'suffix' => :Suffix,
        'veteranrelationship' => :VeteranRelationship,
        'dependentrelationship' => :DependantRelationship,
        'responsetype' => :ResponseType
      }
    end

    def fetch_translation_map(key)
      @translation_cache[key] ||= I18n.t("ask_va_api.parameters.#{key}")
    end

    def log_error(action, exception)
      logger.call(action) do |span|
        span.set_tag('error', true)
        span.set_tag('error.msg', exception.message)
      end
      Rails.logger.error("Error during #{action}: #{exception.message}")
    end
  end
end
