# frozen_string_literal: true
require 'common/client/configuration/soap'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'
require 'common/client/middleware/response/snakecase'
require 'preneeds/middleware/response/clean_response'
require 'preneeds/middleware/response/soap_to_json'

module Preneeds
  class Configuration < Common::Client::Configuration::SOAP
    def base_path
      Settings.preneeds.endpoint
    end

    def connection
      @faraday ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.options.open_timeout = Settings.preneeds.open_timeout
        conn.options.timeout = Settings.preneeds.timeout

        conn.response :snakecase
        conn.response :soap_to_json
        conn.response :soap_parser
        conn.response :mhv_xml_html_errors
        conn.response :clean_response

        conn.use :breakers
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
