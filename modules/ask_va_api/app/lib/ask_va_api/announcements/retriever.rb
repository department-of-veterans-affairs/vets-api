# frozen_string_literal: true

module AskVAApi
  module Announcements
    ENDPOINT = 'announcements'

    class Retriever < BaseRetriever
      attr_reader :name

      def initialize(user_mock_data:, entity_class:)
        super(user_mock_data:, entity_class:)
      end

      private

      def fetch_data
        if user_mock_data
          data = File.read('modules/ask_va_api/config/locales/get_announcements_mock_data.json')
          JSON.parse(data, symbolize_names: true)[:Data]
        else
          fetch_service_data[:Data]
        end
      end

      def default_service
        Crm::Service.new(icn: nil)
      end

      def fetch_service_data
        default_service.call(endpoint: ENDPOINT)
      end
    end
  end
end
