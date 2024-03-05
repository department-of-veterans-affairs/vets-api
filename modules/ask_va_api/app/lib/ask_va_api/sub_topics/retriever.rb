# frozen_string_literal: true

module AskVAApi
  module SubTopics
    class Retriever < BaseRetriever
      attr_reader :topic_id

      def initialize(topic_id:, user_mock_data:, entity_class:)
        super(user_mock_data:, entity_class:)
        @topic_id = topic_id
      end

      private

      def filter_data(data)
        data[:Topics].select { |t| t[:ParentId] == topic_id }.sort_by { |sub| sub[:Name] }
      end
    end
  end
end
