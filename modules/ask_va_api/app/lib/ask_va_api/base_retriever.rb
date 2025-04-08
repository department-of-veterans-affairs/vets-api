# frozen_string_literal: true

module AskVAApi
  class BaseRetriever
    attr_reader :user_mock_data, :entity_class

    def initialize(user_mock_data:, entity_class:)
      @user_mock_data = user_mock_data
      @entity_class = entity_class
    end

    def call
      data = fetch_data

      return data.map { |item| entity_class.new(item) } if data.is_a?(Array)

      entity_class.new(data)
    rescue => e
      ::ErrorHandler.handle_service_error(e)
    end

    private

    def fetch_data
      raise NotImplementedError, 'Subclasses must implement the filter_data method'
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
