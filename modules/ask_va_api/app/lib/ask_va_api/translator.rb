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
      payload = convert_keys_to_pascal_case(inquiry_params, fetch_translation_map('inquiry'))

      options.each do |option|
        update_option_in_payload(payload, option)
      end

      payload
    end

    private

    def convert_keys_to_pascal_case(params, translation_map)
      params.each_with_object({}) do |(key, value), result|
        pascal_case_key = translation_map[key.to_sym]
        next unless pascal_case_key

        result[pascal_case_key.to_sym] = case value
                                         when Hash
                                           convert_keys_to_pascal_case(value, fetch_translation_map(key))
                                         when Array
                                           value.map { |v| convert_keys_to_pascal_case(v, fetch_translation_map(key)) }
                                         else
                                           value
                                         end
      end
    end

    def update_option_in_payload(payload, option)
      option_key = options_converter_hash[option]
      return unless option_key

      option_set = retrieve_option_set(option)

      if option == 'suffix'
        update_suffix(payload, option_set)
      else
        update_option(payload, option_key, option_set)
      end
    rescue => e
      log_and_raise_error("update option #{option}", e)
    end

    def update_suffix(payload, option_set)
      %i[Suffix VeteranSuffix Profile].each do |suffix_key|
        suffix_value = suffix_key == :Profile ? payload.dig(:Profile, :suffix) : payload[suffix_key]
        matching_option = option_set.find { |obj| obj.name == suffix_value }

        if suffix_key == :Profile
          payload[:Profile][:suffix] = matching_option.id if matching_option
        elsif matching_option
          payload[suffix_key] = matching_option.id
        end
      end
    end

    def update_option(payload, option_key, option_set)
      matching_option = option_set.find { |obj| obj.name == payload[option_key] }
      payload[option_key] = matching_option.id if matching_option
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
      @translation_cache[key] ||= I18n.t("ask_va_api.parameters.#{key}", default: {})
    end

    def log_and_raise_error(action, exception)
      log_error(action, exception)
      raise TranslatorError, exception if exception.message.include?('Crm::CacheDataError')
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
