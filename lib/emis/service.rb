# frozen_string_literal: true

require 'common/client/base'
require 'emis/configuration'
require 'emis/messages/edipi_or_icn_message'
require 'emis/responses'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'

module EMIS
  class Service < Common::Client::Base
    def self.create_endpoints(endpoints)
      endpoints.each do |endpoint|
        operation = nil
        request_name = nil
        if endpoint.is_a?(Array)
          request_name = endpoint[1]
          operation = endpoint[0].to_s
        else
          operation = endpoint.to_s
          request_name = "#{endpoint.to_s.camelize(:lower).sub(/^get/, '').camelize(:lower)}Request"
        end
        define_method(operation) do |edipi: nil, icn: nil|
          make_request(
            edipi: edipi,
            icn: icn,
            request_name: request_name,
            operation: operation,
            response_type: "EMIS::Responses::#{operation.camelize}Response".constantize
          )
        end
      end
    end

    protected

    def make_request(edipi: nil, icn: nil, response_type:, operation:, request_name:)
      message = create_edipi_or_icn_message(
        edipi: edipi,
        icn: icn,
        request_name: request_name
      )
      raw_response = perform(
        :post,
        '',
        message,
        soapaction: "http://viers.va.gov/cdi/eMIS/#{operation.camelize(:lower)}/v1"
      )
      response_type.new(raw_response)
      # :nocov:
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error "eMIS connection failed: #{e.message}"
      EMIS::Responses::ErrorResponse.new(e)
    rescue Common::Client::Errors::ClientError => e
      Rails.logger.error "eMIS error: #{e.message}"
      EMIS::Responses::ErrorResponse.new(e)
      # :nocov:
    end

    def create_edipi_or_icn_message(edipi:, icn:, request_name:)
      EMIS::Messages::EdipiOrIcnMessage.new(
        edipi: edipi,
        icn: icn,
        request_name: request_name,
        custom_namespaces: custom_namespaces
      ).to_xml
    end
  end
end
