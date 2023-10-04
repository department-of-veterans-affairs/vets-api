# frozen_string_literal: true

module AskVAApi
  module Correspondences
    ENDPOINT = 'get_replies_mock_data'
    URI = 'example.com'

    class Retriever
      attr_reader :inquiry_number, :service

      def initialize(inquiry_number:, service: nil)
        @inquiry_number = inquiry_number
        @service = service || default_service
      end

      def call
        validate_input(inquiry_number, 'Invalid Inquiry Number')
        correspondences = fetch_data(criteria: { inquiry_number: })
        Entity.new(correspondences)
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def default_service
        # mock = !Rails.env.production?
        mock = true

        Dynamics::Service.new(base_uri: URI, sec_id: nil, mock:)
      end

      def fetch_data(criteria: {})
        service.call(endpoint: ENDPOINT, criteria:)
      end

      def validate_input(input, error_message)
        raise ArgumentError, error_message if input.blank?
      end
    end
  end
end
