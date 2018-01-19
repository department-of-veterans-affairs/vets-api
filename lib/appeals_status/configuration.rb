# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/response/caseflow_errors'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'

module AppealsStatus
  # Configuration class used to setup the environment used by client
  class Configuration < Common::Client::Configuration::REST
    def app_token
      Settings.appeals_status.app_token
    end

    def base_path
      "#{Settings.appeals_status.host}/api/v2/appeals"
    end

    def service_name
      'AppealsStatus'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options, ssl: { verify: false }) do |conn|
        conn.use :breakers
        conn.request :json
        conn.response :snakecase
        conn.response :raise_error, error_prefix: service_name
        conn.response :caseflow_errors
        conn.response :json_parser
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
