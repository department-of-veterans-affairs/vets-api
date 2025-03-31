# frozen_string_literal: true

require 'common/client/configuration/soap'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'
require 'preneeds/middleware/response/clean_response'
require 'preneeds/middleware/response/eoas_xml_errors'
require 'preneeds/middleware/response/preneeds_parser'

module Preneeds
  # Configuration for the {Preneeds::Service} to communicate to
  # set the base path, a default timeout, and a service name for breakers and metrics.
  # Communicates with the EOAS external service.
  #
  class Configuration < Common::Client::Configuration::SOAP
    # Number of seconds before timeout
    #
    TIMEOUT = 30

    # @return [String] The base path for the external EOAS service
    #
    def self.url
      "#{Settings.preneeds.host}/eoas_SOA/PreNeedApplicationPort"
    end

    # (see .url)
    #
    def base_path
      self.class.url
    end

    # @return [String] The name of the service, used by breakers to set a metric name for the service
    #
    def service_name
      'Preneeds'
    end

    # Creates the a connection with middleware for mapping errors, parsing XML, and adding breakers functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      path = Preneeds::Configuration.url
      @faraday ||= Faraday.new(
        path, headers: base_request_headers, request: request_options, ssl: { verify: false }
      ) do |conn|
        conn.use(:breakers, service_name:)

        conn.options.timeout = TIMEOUT

        conn.request :soap_headers

        conn.response :preneeds_parser
        conn.response :soap_parser
        conn.response :eoas_xml_errors
        conn.response :clean_response

        conn.adapter Faraday.default_adapter
      end
    end
  end
end
