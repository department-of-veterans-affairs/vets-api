# frozen_string_literal: true

module AskVAApi
  module Correspondences
    class CorrespondencesCreatorError < StandardError; end

    class Creator
      attr_reader :message, :inquiry_id, :service

      def initialize(message:, inquiry_id:, service:)
        @message = message
        @inquiry_id = inquiry_id
        @service = service || default_service
      end

      def call
        payload = { Reply: message }
        post_data(payload:)
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def default_service
        Crm::Service.new(icn: nil)
      end

      def post_data(payload: {})
        endpoint = "inquiries/#{inquiry_id}/reply/new"

        response = service.call(endpoint:, method: :put, payload:)
        handle_response_data(response)
      end

      def handle_response_data(response)
        case response
        when Hash
          response[:Data]
        else
          raise(CorrespondencesCreatorError, response.body)
        end
      end
    end
  end
end
