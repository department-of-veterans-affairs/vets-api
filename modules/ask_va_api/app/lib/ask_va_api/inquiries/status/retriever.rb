# frozen_string_literal: true

module AskVAApi
  module Inquiries
    module Status
      ENDPOINT = 'inquirystatus'

      class Retriever
        class RetrievalError < StandardError; end
        class ServiceError < StandardError; end

        attr_reader :icn, :service

        def initialize(icn:, service: nil)
          @icn = icn
          @service = service || default_service
        end

        def call(inquiry_number:)
          payload = { inquiryNumber: inquiry_number }
          data = fetch_data(payload:)

          Entity.new(data)
        rescue ServiceError => e
          raise RetrievalError, "Failed to retrieve inquiry status: #{e.message}"
        end

        private

        def default_service
          Crm::Service.new(icn:)
        end

        def fetch_data(payload: {})
          data = service.call(endpoint: ENDPOINT, payload:)
          validate_data!(data)
          data
        end

        def validate_data!(data)
          if data[:Status].nil?
            error = JSON.parse(data[:body], symbolize_names: true)
            raise ServiceError, error[:Message]
          end
        end
      end
    end
  end
end
