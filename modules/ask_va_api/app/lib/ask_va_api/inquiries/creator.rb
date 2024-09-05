# frozen_string_literal: true

module AskVAApi
  module Inquiries
    class InquiriesCreatorError < StandardError; end

    class Creator
      ENDPOINT = 'inquiries/new'
      attr_reader :icn, :service

      def initialize(icn:, service: nil)
        @icn = icn
        @service = service || default_service
      end

      def call(payload:)
        post_data(payload:)
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def default_service
        Crm::Service.new(icn:)
      end

      def post_data(payload: {})
        response = service.call(endpoint: ENDPOINT, method: :put, payload:)
        handle_response_data(response)
      end

      def handle_response_data(response)
        case response
        when Hash
          response[:Data]
        else
          raise(InquiriesCreatorError, response.body)
        end
      end
    end
  end
end
