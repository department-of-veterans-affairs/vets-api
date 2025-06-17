# frozen_string_literal: true

require 'common/client/configuration/soap'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'

module HCA
  class Configuration < Common::Client::Configuration::SOAP
    HEALTH_CHECK_ID = 377_609_264
    WSDL = Rails.root.join('config', 'health_care_application', 'wsdl', 'voa.wsdl')

    def base_path
      Settings.hca.endpoint
    end

    def service_name
      'HCA'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.options.open_timeout = 10
        conn.options.timeout = Settings.hca.timeout
        conn.request :soap_headers
        conn.response :hca_soap_parser
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
