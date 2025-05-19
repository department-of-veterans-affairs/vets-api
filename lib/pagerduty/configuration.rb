# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_custom_error'

module PagerDuty
  class Configuration < Common::Client::Configuration::REST
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :json

        conn.response :raise_custom_error, error_prefix: service_name
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

    def self.service_map
      Settings.maintenance.services&.to_hash&.invert || {}
    end

    def self.service_ids
      Settings.maintenance.services&.to_hash&.values || []
    end
  end
end
