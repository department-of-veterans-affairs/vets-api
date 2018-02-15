# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/response/caseflow_errors'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'

module Appeals
  class Configuration < Common::Client::Configuration::REST
    def app_token
      Settings.appeals.app_token
    end

    def base_path
      "#{Settings.appeals.host}/api/v2/appeals"
    end

    def service_name
      'AppealsStatus'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use :breakers
        faraday.use Faraday::Response::RaiseError
        faraday.request :json
        faraday.response :betamocks if mock_enabled?
        faraday.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      [true, 'true'].include?(Settings.appeals.mock)
    end
  end
end
