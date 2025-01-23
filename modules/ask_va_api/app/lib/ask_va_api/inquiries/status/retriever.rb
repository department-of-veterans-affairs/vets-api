# frozen_string_literal: true

module AskVAApi
  module Inquiries
    module Status
      class StatusRetrieverError < StandardError; end

      class Retriever < BaseRetriever
        ENDPOINT = 'inquirystatus'

        attr_reader :icn, :service, :inquiry_number

        def initialize(inquiry_number:, icn: nil, **args)
          super(**args)
          @icn = icn
          @inquiry_number = inquiry_number
          @service = Crm::Service.new(icn:)
        end

        private

        def fetch_data
          payload = { InquiryNumber: inquiry_number }
          response = service.call(endpoint: ENDPOINT, payload:)
          handle_response_data(response:, error_class: StatusRetrieverError)
        end
      end
    end
  end
end
