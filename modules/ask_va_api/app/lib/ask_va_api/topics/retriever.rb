# frozen_string_literal: true

module AskVAApi
  module Topics
    class Retriever
      attr_reader :user_mock_data,
                  :category_id

      def initialize(category_id:, user_mock_data:)
        @user_mock_data = user_mock_data
        @category_id = category_id
      end

      def call
        topics_array = fetch_data

        topics_array.map do |topic|
          Entity.new(topic)
        end
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def fetch_data
        data = if user_mock_data
                 static = File.read('modules/ask_va_api/config/locales/static_data.json')
                 JSON.parse(static, symbolize_names: true)
               else
                 Crm::StaticData.new.call
               end

        data[:Topics].select { |t| t[:parentId] == category_id }
      end
    end
  end
end
