# frozen_string_literal: true

module AskVAApi
  module Correspondences
    class CorrespondencesRetrieverError < StandardError; end

    class Retriever < BaseRetriever
      attr_reader :inquiry_id, :entity_class

      def initialize(inquiry_id:, user_mock_data:, entity_class:)
        super(user_mock_data:, entity_class:)
        @inquiry_id = inquiry_id
      end

      private

      def fetch_data
        validate_input(inquiry_id, 'Invalid Inquiry ID')
        if user_mock_data
          data = File.read('modules/ask_va_api/config/locales/get_replies_mock_data.json')

          data = JSON.parse(data, symbolize_names: true)[:Data]
          filter_data(data)
        else
          endpoint = "inquiries/#{inquiry_id}/replies"

          response = Crm::Service.new(icn: nil).call(endpoint:)
          handle_response_data(response)
        end
      end

      def validate_input(input, error_message)
        raise ArgumentError, error_message if input.blank?
      end

      def filter_data(data)
        data.select do |cor|
          cor[:InquiryId] == inquiry_id
        end
      end

      def handle_response_data(response)
        response[:Data].presence || raise(CorrespondencesRetrieverError, response[:Message])
      end
    end
  end
end
