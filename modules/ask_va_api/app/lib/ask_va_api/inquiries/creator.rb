# frozen_string_literal: true

module AskVAApi
  module Inquiries
    class Creator
      ENDPOINT = 'inquiries/new'
      attr_reader :icn, :service

      def initialize(icn:, service: nil)
        @icn = icn
        @service = service || default_service
      end

      def call(params:)
        post_data(payload: { params: })
        { message: 'Inquiry has been created', status: :ok }
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def default_service
        Dynamics::Service.new(icn:)
      end

      def post_data(payload: {})
        service.call(endpoint: ENDPOINT, method: :post, payload:)
      end
    end
  end
end
