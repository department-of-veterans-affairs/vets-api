# frozen_string_literal: true

module AskVAApi
  module Inquiries
    ENDPOINT = 'get_inquiries_mock_data'

    class Retriever
      attr_reader :service, :sec_id

      def initialize(sec_id:, service: nil)
        @sec_id = sec_id
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

      def fetch_by_sec_id
        validate_input(sec_id, 'Invalid SEC_ID')
        fetch_data(payload: { sec_id: }).map { |inq| Entity.new(inq) }
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def default_service
        Dynamics::Service.new(sec_id:)
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
