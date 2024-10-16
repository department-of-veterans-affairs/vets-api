# frozen_string_literal: true

module AskVAApi
  module Attachments
    ENDPOINT = 'attachment'
    class AttachmentsRetrieverError < StandardError; end

    class Retriever < BaseRetriever
      attr_reader :id, :service

      def initialize(id:, service: nil, **args)
        super(**args)
        @id = id
        @service = service || default_service
      end

      private

      def default_service
        Crm::Service.new(icn: nil)
      end

      def fetch_data
        validate_input(id, "Invalid Attachment's ID")
        response = service.call(endpoint: ENDPOINT, payload: { id: })
        handle_response_data(response:, error_class: AttachmentsRetrieverError)
      end

      def validate_input(input, error_message)
        raise ArgumentError, error_message if input.blank?
      end
    end
  end
end
