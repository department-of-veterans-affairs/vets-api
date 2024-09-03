# frozen_string_literal: true

module AskVAApi
  module Inquiries
    class InquiriesRetrieverError < StandardError; end

    class Retriever < BaseRetriever
      attr_reader :icn, :user_mock_data, :entity_class

      def initialize(user_mock_data:, entity_class:, icn: nil)
        super(user_mock_data:, entity_class:)
        @icn = icn
      end

      def fetch_by_id(id:)
        inq = fetch_data(id)
        reply = fetch_correspondences(inquiry_id: id)

        entity_class.new(inq.first, reply)
      rescue => e
        ::ErrorHandler.handle_service_error(e)
      end

      private

      def fetch_data(id = nil)
        if user_mock_data
          data = read_mock_data('get_inquiries_mock_data.json')
          filter_data(data, id)
        else
          endpoint = 'inquiries'
          id ||= icn
          payload = { id: }

          response = Crm::Service.new(icn:).call(endpoint:, payload:)
          handle_response_data(response:, error_class: InquiriesRetrieverError)
        end
      end

      def fetch_correspondences(inquiry_id:)
        correspondences = Correspondences::Retriever.new(
          inquiry_id:,
          user_mock_data:,
          entity_class: AskVAApi::Correspondences::Entity
        ).call

        case correspondences
        when String
          []
        else
          correspondences
        end
      end

      def read_mock_data(file_name)
        data = File.read("modules/ask_va_api/config/locales/#{file_name}")
        JSON.parse(data, symbolize_names: true)[:Data]
      end

      def filter_data(data, id = nil)
        data.select do |inq|
          id ? inq[:InquiryNumber] == id : inq[:Icn] == icn
        end
      end
    end
  end
end
