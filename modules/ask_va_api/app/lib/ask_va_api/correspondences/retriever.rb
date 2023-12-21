# frozen_string_literal: true

module AskVAApi
  module Correspondences
    ENDPOINT = 'get_replies_mock_data'

    class Retriever
      attr_reader :id, :service

      def initialize(id:, service: nil)
        @id = id
        @service = service || default_service
      end

      def call
        validate_input(id, 'Invalid Inquiry ID')
        fetch_data(payload: { id: }).map do |cor|
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
