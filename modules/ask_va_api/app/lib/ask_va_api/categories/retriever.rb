# frozen_string_literal: true

module AskVAApi
  module Categories
    class Retriever
      attr_reader :user_mock_data

      def initialize(user_mock_data: false)
        @user_mock_data = user_mock_data
      end

      def call
        categories_array = fetch_data

        categories_array.map do |cat|
          Entity.new(cat)
        end
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def fetch_data
        data = if user_mock_data
                 File.read('modules/ask_va_api/config/locales/static_data.json')
               else
                 Crm::StaticData.new.call
               end

        JSON.parse(data, symbolize_names: true)[:Topics].select { |t| t[:parentId].nil? }
      end
    end
  end
end
