# frozen_string_literal: true

module AskVAApi
  module Categories
    class Retriever < BaseRetriever
      private

      def filter_data(data)
        data[:Topics].select { |t| t[:ParentId].nil? }.sort_by { |cat| cat[:RankOrder] }
      end
    end
  end
end
