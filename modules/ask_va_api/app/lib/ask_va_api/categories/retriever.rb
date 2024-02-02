# frozen_string_literal: true

module AskVAApi
  module Categories
    class Retriever < BaseRetriever
      private

      def filter_data(data)
        data[:Topics].select { |t| t[:parentId].nil? }
      end
    end
  end
end
