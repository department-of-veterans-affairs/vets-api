# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'

module PagerDuty
  class Configuration < Common::Client::Configuration::REST
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.request :json

        conn.response :raise_error, error_prefix: service_name, exception_class: service_exception
        conn.response :json_parser

        conn.adapter Faraday.default_adapter
      end
    end

    def base_path
      Settings.maintenance.pagerduty_api_url
    end

    def service_name
      'PagerDuty'
    end
  end
end
