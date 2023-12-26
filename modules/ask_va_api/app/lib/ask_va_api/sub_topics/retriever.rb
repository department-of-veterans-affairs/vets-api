# frozen_string_literal: true

module AskVAApi
  module SubTopics
    ENDPOINT = 'get_subtopics_mock_data'

    class Retriever
      attr_reader :service, :topic_id

      def initialize(topic_id:, service: nil)
        @service = service || default_service
        @topic_id = topic_id
      end

      def call
        subtopics_array = fetch_data(payload: { topic_id: })

        subtopics_array.map do |sub|
          Entity.new(sub)
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
