# frozen_string_literal: true

module AskVAApi
  module Correspondences
    ENDPOINT = 'get_replies_mock_data'

    class Retriever
      attr_reader :inquiry_id, :service

      def initialize(inquiry_id:, service: nil)
        @inquiry_id = inquiry_id
        @service = service || default_service
      end

      def call
        validate_input(inquiry_id, 'Invalid Inquiry ID')
        fetch_data(payload: { inquiry_id: }).map do |cor|
          Entity.new(cor)
        end
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def default_service
        Crm::Service.new(icn: nil)
      end

      def fetch_data(payload: {})
        service.call(endpoint: ENDPOINT, payload:)
      end

      def validate_input(input, error_message)
        raise ArgumentError, error_message if input.blank?
      end
    end
  end
end
