# frozen_string_literal: true

module AskVAApi
  class BaseRetriever
    attr_reader :user_mock_data, :entity_class

    def initialize(user_mock_data:, entity_class:)
      @user_mock_data = user_mock_data
      @entity_class = entity_class
    end

    def call
      if fetch_data.is_a?(Array)
        fetch_data.map { |item| entity_class.new(item) }
      else
        entity_class.new(fetch_data)
      end
    rescue => e
      ::ErrorHandler.handle_service_error(e)
    end

    private

    def fetch_data
      data = if user_mock_data
               static = File.read('modules/ask_va_api/config/locales/static_data.json')
               JSON.parse(static, symbolize_names: true)
             else
               Crm::CacheData.new.call(endpoint: 'Topics', cache_key: 'categories_topics_subtopics')
             end
      filter_data(data)
    end

    def filter_data(data)
      raise NotImplementedError, 'Subclasses must implement the filter_data method'
    end

    def handle_response_data(response:, error_class:)
      return response[:Data] if response.is_a?(Hash)

      raise(error_class, response.body)
    end
  end
end
