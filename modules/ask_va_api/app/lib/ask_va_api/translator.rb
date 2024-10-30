# frozen_string_literal: true

module AskVAApi
  class TranslatorError < StandardError; end

  class Translator
    attr_reader :optionset_entity_class, :retriever, :logger

    def initialize(entity_class: Optionset::Entity)
      @optionset_entity_class = entity_class
      @retriever = Optionset::Retriever
    end

    def call(key)
      return if key.nil?

      retrieve_option_set.find { |obj| key.downcase.include?(obj.name.downcase) }&.id
    end

    private

    def retrieve_option_set
      retriever.new(user_mock_data: nil, entity_class: optionset_entity_class).call
    rescue => e
      raise TranslatorError, e if e.message.include?('Crm::CacheDataError')
    end
  end
end
