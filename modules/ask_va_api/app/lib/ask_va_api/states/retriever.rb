# frozen_string_literal: true

module AskVAApi
  module States
    ENDPOINT = 'get_states_mock_data.json'

    class Retriever
      def initialize(service: nil)
        @service = service
      end

      def call
        states_array = fetch_data

        states_array.map do |state|
          Entity.new(state)
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
