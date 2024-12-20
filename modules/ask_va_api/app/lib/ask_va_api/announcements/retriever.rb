# frozen_string_literal: true

module AskVAApi
  module Announcements
    class AnnouncementsRetrieverError < StandardError; end

    ENDPOINT = 'announcements'

    class Retriever < BaseRetriever
      private

      def fetch_data
        if user_mock_data
          data = File.read('modules/ask_va_api/config/locales/get_announcements_mock_data.json')
          JSON.parse(data, symbolize_names: true)[:Data]
        else
          fetch_service_data
        end
      end

      def default_service
        Crm::Service.new(icn: nil)
      end

      def fetch_service_data
        response = default_service.call(endpoint: ENDPOINT)
        handle_response_data(response:, error_class: AnnouncementsRetrieverError)
      end
    end
  end
end
