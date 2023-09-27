# frozen_string_literal: true

module AskVAApi
  module Inquiries
    ENDPOINT = 'get_inquiries_mock_data'
    URI = 'example.com'
    class Retriever
      def initialize(sec_id:, service: nil)
        @sec_id = sec_id
        @service = service || default_service
      end

      def fetch_by_inquiry_number(inquiry_number:)
        validate_input(inquiry_number, 'Invalid Inquiry Number')
        reply = Replies::ReplyCreator.new(inquiry_number:).call
        data = fetch_data(criteria: { inquiry_number: })
        Entity.new(data, reply)
      end

      def fetch_by_sec_id
        validate_input(sec_id, 'Invalid SEC_ID')
        fetch_data(criteria: { sec_id: }).map { |inq| Entity.new(inq) }
      end

      private

      attr_reader :service, :sec_id

      def default_service
        mock = !Rails.env.production?
        Dynamics::Service.new(base_uri: URI, sec_id:, mock:)
      end

      def fetch_data(criteria: {})
        service.call(endpoint: ENDPOINT, criteria:)
      rescue Dynamics::ErrorHandler::ServiceError => e
        ErrorHandler.handle_service_error(e)
      end

      def validate_input(input, error_message)
        raise ArgumentError, error_message if input.blank?
      end
    end
  end
end
