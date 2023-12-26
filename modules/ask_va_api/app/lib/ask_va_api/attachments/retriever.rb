# frozen_string_literal: true

module AskVAApi
  module Attachments
    ENDPOINT = 'get_attachments_mock_data'

    class Retriever
      attr_reader :id, :service

      def initialize(id:, service: nil)
        @id = id
        @service = service || default_service
      end

      def call
        validate_input(id, "Invalid Attachment's ID")

        attachments = fetch_data(payload: { id: })
        attachments.map do |att|
          Entity.new(att)
        end.first
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
