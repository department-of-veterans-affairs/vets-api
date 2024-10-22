# frozen_string_literal: true

module AskVAApi
  module Optionset
    class OptionsetRetrieverError < StandardError; end

    class Retriever < BaseRetriever
      attr_reader :name

      private

      def fetch_data
        if user_mock_data
          data = File.read('modules/ask_va_api/config/locales/get_optionset_mock_data.json')
          JSON.parse(data, symbolize_names: true)[:Data]
        else
          response = Crm::CacheData.new.call(endpoint: 'optionset', cache_key: 'optionset')
          result = handle_response_data(response:, error_class: OptionsetRetrieverError)
          result.pluck(:ListOfOptions).flatten
        end
      end
    end
  end
end
