# frozen_string_literal: true

module AskVAApi
  module Inquiries
    ENDPOINT = 'inquiries'

    class Retriever
      attr_reader :service, :icn

      def initialize(icn:, service: nil)
        @icn = icn
        @service = service || default_service
      end

      def fetch_by_id(id:)
        validate_input(id, 'Invalid ID')
        reply = Correspondences::Retriever.new(inquiry_id: id, service:).call
        data = fetch_data(payload: { id: })
        return {} if data.blank?

        Entity.new(data, reply)
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      def fetch_by_icn
        validate_input(icn, 'Invalid ICN')
        data = fetch_data(payload: { icn: })
        if data.empty?
          data
        else
          data.map { |inq| Entity.new(inq) }
        end
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def default_service
        Crm::Service.new(icn:)
      end

      def fetch_data(payload: {})
        service.call(endpoint: ENDPOINT, payload:)[:Data]
      end

      def validate_input(input, error_message)
        raise ArgumentError, error_message if input.blank?
      end
    end
  end
end
