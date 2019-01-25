# frozen_string_literal: true

require 'appeals/middleware/errors'
require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_error'

module Appeals
  class Configuration < Common::Client::Configuration::REST
    def app_token
      Settings.appeals.app_token
    end

    def base_path
      Settings.appeals.host
    end

    def service_name
      'AppealsStatus'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use :breakers
        faraday.request :json

        faraday.response :raise_error, error_prefix: service_name
        faraday.response :appeals_errors
        faraday.response :betamocks if mock_enabled?
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      [true, 'true'].include?(Settings.appeals.mock)
    end
  end
end
