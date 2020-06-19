# frozen_string_literal: true

require 'common/client/configuration/rest'

module MDOT
  class Configuration < Common::Client::Configuration::REST
    def service_name
      'MDOT'
    end

    def base_path
      Settings.mdot.url
    end

    def connection
      @connection = Faraday.new(base_path, headers: base_request_headers, request: request_options) do |f|
        f.use :breakers
        f.request :json
        f.use Faraday::Response::RaiseError
        f.response :betamocks if mock_enabled?
        f.response :snakecase, symbolize: false
        f.response :json
        f.adapter Faraday.default_adapter

        # TODO: remove long timeouts after changing to real API
        f.options.timeout = 30
        f.options.open_timeout = 30
      end
    end

    def mock_enabled?
      Settings.mdot.mock || false
    end
  end
end
