# frozen_string_literal: true
require 'common/client/configuration/soap'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'
require 'common/client/middleware/response/snakecase'
require 'burials/middleware/response/clean_response'
require 'burials/middleware/response/soap_to_json'

module Burials
  class Configuration < Common::Client::Configuration::SOAP
    def base_path
      Settings.burials.endpoint
    end

    def connection
      @faraday ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.options.open_timeout = Settings.burials.open_timeout
        conn.options.timeout = Settings.burials.timeout

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
