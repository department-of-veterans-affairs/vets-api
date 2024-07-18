# frozen_string_literal: true

module AskVAApi
  module Inquiries
    module Status
      class StatusRetrieverError < StandardError; end

      class Retriever < BaseRetriever
        ENDPOINT = 'inquirystatus'

        attr_reader :icn, :service, :inquiry_number

        def initialize(user_mock_data:, entity_class:, inquiry_number:, icn: nil)
          super(user_mock_data:, entity_class:)
          @icn = icn
          @inquiry_number = inquiry_number
          @service = Crm::Service.new(icn:)
        end

        private

        def fetch_data
          payload = { InquiryNumber: inquiry_number }
          response = service.call(endpoint: ENDPOINT, payload:)
          handle_response_data(response)
        end

        def handle_response_data(response)
          case response
          when Hash
            response[:Data]
          else
            error = JSON.parse(response.body, symbolize_names: true)
            raise(StatusRetrieverError, error[:Message])
          end
        end
      end
    end
  end
end
