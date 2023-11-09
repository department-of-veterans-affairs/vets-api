# frozen_string_literal: true

module AskVAApi
  module Provinces
    ENDPOINT = 'get_provinces_mock_data.json'

    class Retriever
      def initialize(service: nil)
        @service = service
      end

      def call
        provinces_array = fetch_data

        provinces_array.map do |data|
          Entity.new(data)
        end
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def fetch_data
        file_path = "modules/ask_va_api/config/locales/#{ENDPOINT}"

        JSON.parse(File.read(file_path), symbolize_names: true)[:data]
      end
    end
  end
end
