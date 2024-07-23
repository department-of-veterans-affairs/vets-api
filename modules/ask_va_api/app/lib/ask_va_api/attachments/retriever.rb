# frozen_string_literal: true

module AskVAApi
  module Attachments
    ENDPOINT = 'attachment'
    class AttachmentsRetrieverError < StandardError; end

    class Retriever
      attr_reader :id, :service

      def initialize(id:, service: nil)
        @id = id
        @service = service || default_service
      end

      def call
        validate_input(id, "Invalid Attachment's ID")

        attachment = fetch_data(payload: { id: })

        Entity.new(attachment)
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def default_service
        Crm::Service.new(icn: nil)
      end

      def fetch_data(payload: {})
        response = service.call(endpoint: ENDPOINT, payload:)
        handle_response_data(response)
      end

      def validate_input(input, error_message)
        raise ArgumentError, error_message if input.blank?
      end

      def handle_response_data(response)
        case response
        when Hash
          response[:Data]
        else
          error = JSON.parse(response.body, symbolize_names: true)
          raise(AttachmentsRetrieverError, error[:Message])
        end
      end
    end
  end
end
