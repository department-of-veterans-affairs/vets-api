# frozen_string_literal: true

module AskVAApi
  module Topics
    ENDPOINT = 'get_topics_mock_data'

    class Retriever
      attr_reader :service, :category_id

      def initialize(category_id:, service: nil)
        @service = service || default_service
        @category_id = category_id
      end

      def call
        topics_array = fetch_data(payload: { category_id: })

        topics_array.map do |topic|
          Entity.new(topic)
        end
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def default_service
        Crm::Service.new(icn: nil)
      end

      def fetch_data(payload:)
        service.call(endpoint: ENDPOINT, payload:)
      end
    end
  end
end
