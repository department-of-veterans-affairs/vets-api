# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_custom_error'

module Facilities
  class BulkJSONConfiguration < Common::Client::Configuration::REST
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.request :json

        conn.response :raise_custom_error, error_prefix: service_name
        conn.response :json_parser

        conn.adapter Faraday.default_adapter
      end
    end
  end

  class AccessWaitTimeConfiguration < BulkJSONConfiguration
    def base_path
      Settings.locators.vha_access_waittime
    end

    def service_name
      'VHA_Access_PWT'
    end
  end

  class AccessSatisfactionConfiguration < BulkJSONConfiguration
    def base_path
      Settings.locators.vha_access_satisfaction
    end

    def service_name
      'VHA_Access_SHEP'
    end
  end
end
