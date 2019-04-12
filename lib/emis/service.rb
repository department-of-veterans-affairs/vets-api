# frozen_string_literal: true

require 'common/client/base'
require 'emis/configuration'
require 'emis/messages/edipi_or_icn_message'
require 'emis/responses'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'

module EMIS
  # HTTP Client for EMIS requests.
  # Requests and responses are SOAP format.
  class Service < Common::Client::Base
    # Prefix string for StatsD monitoring
    STATSD_KEY_PREFIX = 'api.emis'
    include Common::Client::Concerns::LogAsWarningHelpers

    # Create methods for each endpoint in EMIS API.
    #
    # @param endpoints [Array<String, Symbol, Array<String, Symbol>>] An array of endpoints,
    #  either a string or symbol if the method name and endpoint path (converted to camelcase)
    #  are the same or an Array containing the method name and endpoint path.
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

    # Helper for sending requests to the EMIS API
    #
    # @param edipi [String] User's Electronic Data Interchange Personal Identifier
    # @param icn [String] User's Integration Control Number
    # @param response_type [EMIS::Responses] EMIS Response class
    # @param operation [String] API path endpoint
    # @param request_name [String] Request name used in XML request body
    #
    # @return [EMIS::Responses] Whatever +response_type+ was passed in will be returned
    def make_request(edipi: nil, icn: nil, response_type:, operation:, request_name:)
      message = create_edipi_or_icn_message(
        edipi: edipi,
        icn: icn,
        request_name: request_name
      )
      raw_response = warn_for_service_unavailable do
        perform(
          :post,
          '',
          message,
          soapaction: "http://viers.va.gov/cdi/eMIS/#{operation.camelize(:lower)}/v1"
        )
      end
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

    # Creates a SOAP request body that includes user identifiers to send to the EMIS API
    #
    # @param edipi [String] User's Electronic Data Interchange Personal Identifier
    # @param icn [String] User's Integration Control Number
    # @param request_name [String] Request name used in XML request body
    #
    # @return [EMIS::Messages::EdipiOrIcnMessage] SOAP request message
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
