# frozen_string_literal: true

module AskVAApi
  module Topics
    ENDPOINT = 'get_topics_mock_data'
    URI = 'get_topics_from_dynamics.com'

    class Retriever
      attr_reader :service, :category_id

      def initialize(category_id:, service: nil)
        @service = service || default_service
        @category_id = category_id
      end

      def call
        topics_array = fetch_data(criteria: { category_id: })

        topics_array.map do |topic|
          Entity.new(topic)
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
