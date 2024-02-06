# frozen_string_literal: true

module AskVAApi
  module Categories
    class Retriever < BaseRetriever
      private

      def filter_data(data)
        data[:Topics].select { |t| t[:parentId].nil? }.sort_by { |cat| cat[:rankOrder] }
      end
    end
  end
end
