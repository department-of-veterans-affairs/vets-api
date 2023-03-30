# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/log_as_warning_helpers'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'
require 'emis/configuration'
require 'emis/messages/edipi_or_icn_message'
require 'emis/responses'

module EMIS
  # HTTP Client for EMIS requests.
  # Requests and responses are SOAP format
  class Service < Common::Client::Base
    # Prefix string for StatsD monitoring
    STATSD_KEY_PREFIX = 'api.emis'
    include Common::Client::Concerns::LogAsWarningHelpers

    # Create methods for each endpoint in EMIS API.
    #
    # @param endpoints [Array<String, Symbol, Array<String, Symbol>>] An array of endpoints,
    #  either a string or symbol if the method name and endpoint path (converted to camelcase)
    #  are the same or an Array containing the method name, endpoint path,
    #  and optional version of response and soapaction
    def self.create_endpoints(endpoints)
      endpoints.each do |endpoint|
        operation, request_name, version = get_endpoint_attributes(endpoint)
        define_method(operation) do |options|
          edipi, icn = options.values_at(:edipi, :icn)

          parameters = {
            edipi:,
            icn:,
            request_name:,
            operation:,
            response_type: "EMIS::Responses::#{operation.camelize}Response#{version.upcase}".constantize
          }
          parameters[:version] = version unless version.empty?
          make_request(**parameters)
        end
      end
    end

    # Helper for extracting endpoint attributes from the endpoint configuration
    #
    # @param endpoint [String, Symbol, Array<String, Symbol>]
    #  Either a string or symbol if the method name and endpoint path (converted to camelcase)
    #  are the same or an Array containing the method name, endpoint path,
    #  and optional version of response and soapaction
    #
    # @return [Array<String, Symbol>] An array containing the method name, endpoint path,
    #  and version of response and soapaction
    def self.get_endpoint_attributes(endpoint)
      operation = nil
      request_name = nil
      if endpoint.is_a?(Array)
        operation = endpoint[0].to_s
        request_name = endpoint[1]
        version = endpoint[2] || ''
      else
        operation = endpoint.to_s
        request_name = "#{endpoint.to_s.camelize(:lower).sub(/^get/, '').camelize(:lower)}Request"
        version = ''
      end
      [operation, request_name, version]
    end

    protected

    # Helper for sending requests to the EMIS API
    #
    # @param edipi [String] User's Electronic Data Interchange Personal Identifier
    # @param icn [String] User's Integration Control Number
    # @param response_type [EMIS::Responses] EMIS Response class
    # @param operation [String] API path endpoint
    # @param request_name [String] Request name used in XML request body
    # @param version [String] Version for soapaction
    #
    # @return [EMIS::Responses] Whatever +response_type+ was passed in will be returned
    #
    # rubocop:disable Metrics/ParameterLists
    def make_request(response_type:, operation:, request_name:, edipi: nil, icn: nil, version: 'V1')
      message = create_edipi_or_icn_message(
        edipi:,
        icn:,
        request_name:
      )
      raw_response = warn_for_service_unavailable do
        perform(
          :post,
          '',
          message,
          soapaction: "http://viers.va.gov/cdi/eMIS/#{operation.camelize(:lower)}/#{version.downcase}"
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
    # rubocop:enable Metrics/ParameterLists

    # Creates a SOAP request body that includes user identifiers to send to the EMIS API
    #
    # @param edipi [String] User's Electronic Data Interchange Personal Identifier
    # @param icn [String] User's Integration Control Number
    # @param request_name [String] Request name used in XML request body
    #
    # @return [EMIS::Messages::EdipiOrIcnMessage] SOAP request message
    def create_edipi_or_icn_message(edipi:, icn:, request_name:)
      EMIS::Messages::EdipiOrIcnMessage.new(
        edipi:,
        icn:,
        request_name:,
        custom_namespaces:
      ).to_xml
    end
  end
end
