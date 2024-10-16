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

      def call(inquiry_params:)
        payload = build_payload(inquiry_params)
        post_data(payload)
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def default_service
        Crm::Service.new(icn:)
      end

      def build_payload(inquiry_params)
        translated_payload = params_translator(inquiry_params).call
        translated_payload[:VeteranICN] = icn
        translated_payload
      end

      def post_data(payload)
        response = service.call(endpoint: ENDPOINT, method: :put, payload:)
        handle_response_data(response)
      end

      def handle_response_data(response)
        return response[:Data] if response.is_a?(Hash)

        raise InquiriesCreatorError, response.body
      end

      def params_translator(inquiry_params)
        Translator.new(inquiry_params:)
      end
    end
  end
end
