# frozen_string_literal: true

module AskVAApi
  module Categories
    ENDPOINT = 'get_categories_mock_data'

    class Retriever
      attr_reader :service

      def initialize(service: nil)
        @service = service || default_service
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

      def default_service
        Crm::Service.new(icn: nil)
      end

      def fetch_data
        service.call(endpoint: ENDPOINT)
      end
    end
  end
end
