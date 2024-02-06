# frozen_string_literal: true

module AskVAApi
  module Topics
    class Retriever < BaseRetriever
      attr_reader :category_id

      def initialize(category_id:, user_mock_data:, entity_class:)
        super(user_mock_data:, entity_class:)
        @category_id = category_id
      end

      private

      def filter_data(data)
        data[:Topics].select { |t| t[:parentId] == category_id }
      end
    end
  end
end
