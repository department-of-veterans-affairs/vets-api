# frozen_string_literal: true

module AskVAApi
  module Inquiries
    ENDPOINT = 'get_inquiries_mock_data'

    class Retriever
      attr_reader :service, :icn

      def initialize(icn:, service: nil)
        @icn = icn
        @service = service || default_service
      end

      def fetch_by_inquiry_number(inquiry_number:)
        validate_input(inquiry_number, 'Invalid Inquiry Number')
        reply = Correspondences::Retriever.new(inquiry_number:, service:).call
        data = fetch_data(payload: { inquiry_number: })
        Entity.new(data, reply)
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      def fetch_by_icn
        validate_input(icn, 'Invalid SEC_ID')
        fetch_data(payload: { icn: }).map { |inq| Entity.new(inq) }
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def default_service
        Crm::Service.new(icn:)
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
