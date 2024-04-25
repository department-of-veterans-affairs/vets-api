# frozen_string_literal: true

module AskVAApi
  module Correspondences
    class Retriever
      attr_reader :inquiry_id, :entity_class, :user_mock_data

      def initialize(inquiry_id:, user_mock_data:, entity_class:)
        @user_mock_data = user_mock_data
        @entity_class = entity_class
        @inquiry_id = inquiry_id
      end

      def call
        case fetch_data
        when Array
          fetch_data.map { |data| entity_class.new(data) }
        else
          fetch_data
        end
      end

      private

      def fetch_data
        if user_mock_data
          data = File.read('modules/ask_va_api/config/locales/get_replies_mock_data.json')

          data = JSON.parse(data, symbolize_names: true)[:Data]
          filter_data(data)
        else
          endpoint = "inquiry/#{inquiry_id}/replies"

          response = Crm::Service.new(icn: nil).call(endpoint:)
          handle_response_data(response)
        end
      end

      def filter_data(data)
        data.select do |cor|
          cor[:InquiryId] == inquiry_id
        end
      end

      def handle_response_data(response)
        response[:Data].presence || response
      end
    end
  end
end
