# frozen_string_literal: true

module AskVAApi
  module SubTopics
    class Retriever
      attr_reader :user_mock_data,
                  :topic_id

      def initialize(topic_id:, user_mock_data:)
        @user_mock_data = user_mock_data
        @topic_id = topic_id
      end

      def call
        sub_topics_array = fetch_data

        sub_topics_array.map do |sub_topic|
          Entity.new(sub_topic)
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

        data[:Topics].select { |t| t[:parentId] == topic_id }
      end
    end
  end
end
