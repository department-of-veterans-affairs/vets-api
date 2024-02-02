# frozen_string_literal: true

module AskVAApi
  module Optionset
    class Retriever < BaseRetriever
      attr_reader :name

      def initialize(name:, user_mock_data:, entity_class:)
        super(user_mock_data:, entity_class:)
        @name = name
      end

      private

      def fetch_data
        if user_mock_data
          data = File.read("modules/ask_va_api/config/locales/get_#{name}_mock_data.json")
          JSON.parse(data, symbolize_names: true)[:data]
        else
          Crm::CacheData.new.call('optionset', name)
        end
      end
    end
  end
end
