# frozen_string_literal: true

module AskVAApi
  module SubTopics
    ENDPOINT = 'get_subtopics_mock_data'
    URI = 'get_subtopics_from_dynamics.com'

    class Retriever
      attr_reader :service, :topic_id

      def initialize(topic_id:, service: nil)
        @service = service || default_service
        @topic_id = topic_id
      end

      def call
        subtopics_array = fetch_data(criteria: { topic_id: })

        subtopics_array.map do |sub|
          Entity.new(sub)
        end
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def default_service
        # mock = !Rails.env.production?
        mock = true
        Dynamics::Service.new(base_uri: URI, sec_id: nil, mock:)
      end

      def fetch_data(criteria:)
        service.call(endpoint: ENDPOINT, criteria:)
      end
    end
  end
end
