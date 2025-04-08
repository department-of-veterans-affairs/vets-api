# frozen_string_literal: true

require 'common/client/configuration/rest'

module MDOT
  class Configuration < Common::Client::Configuration::REST
    self.open_timeout = Settings.mdot.timeout || 5
    self.read_timeout = Settings.mdot.timeout || 5

    def service_name
      'MDOT'
    end

    def base_path
      Settings.mdot.url
    end

    def connection
      @connection = Faraday.new(base_path, headers: base_request_headers, request: request_options) do |f|
        f.use(:breakers, service_name:)
        f.request :json
        f.use Faraday::Response::RaiseError
        f.response :betamocks if mock_enabled?
        f.response :snakecase, symbolize: false
        f.response :json
        f.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      Settings.mdot.mock || false
    end
  end
end
