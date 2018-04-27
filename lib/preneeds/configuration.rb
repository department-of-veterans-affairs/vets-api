# frozen_string_literal: true

require 'common/client/configuration/soap'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'
require 'preneeds/middleware/response/clean_response'
require 'preneeds/middleware/response/eoas_xml_errors'
require 'preneeds/middleware/response/preneeds_parser'

module Preneeds
  class Configuration < Common::Client::Configuration::SOAP
    TIMEOUT = 30

    def self.url
      "#{Settings.preneeds.host}/eoas_SOA/PreNeedApplicationPort"
    end

    def base_path
      self.class.url
    end

    def service_name
      'Preneeds'
    end

    def connection
      path = Preneeds::Configuration.url
      @faraday ||= Faraday.new(
        path, headers: base_request_headers, request: request_options, ssl: { verify: false }
      ) do |conn|
        conn.options.timeout = TIMEOUT

        conn.request :soap_headers

        conn.response :preneeds_parser
        conn.response :soap_parser
        conn.response :eoas_xml_errors
        conn.response :clean_response

        conn.use :breakers
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
