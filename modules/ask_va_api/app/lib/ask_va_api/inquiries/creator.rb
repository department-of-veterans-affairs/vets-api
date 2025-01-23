# frozen_string_literal: true

module AskVAApi
  module Inquiries
    class InquiriesCreatorError < StandardError; end

    class Creator
      ENDPOINT = 'inquiries/new'
      attr_reader :user, :service

      def initialize(user:, service: nil)
        @user = user
        @service = service || default_service
      end

      def call(inquiry_params:)
        payload = build_payload(inquiry_params)
        post_data(payload)
      rescue => e
        handle_error(e)
      end

      private

      def default_service
        Crm::Service.new(icn: user&.icn)
      end

      def build_payload(inquiry_params)
        PayloadBuilder::InquiryPayload.new(inquiry_params:, user: user).call
      end

      def post_data(payload)
        response = service.call(endpoint: ENDPOINT, method: :put, payload:)
        handle_response(response)
      end

      def handle_response(response)
        response.is_a?(Hash) ? response[:Data] : raise(InquiriesCreatorError, response.body)
      end

      def handle_error(error)
        ErrorHandler.handle_service_error(error)
      end
    end
  end
end
