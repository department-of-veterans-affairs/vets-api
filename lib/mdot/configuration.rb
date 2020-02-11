# frozen_string_literal: true

require 'common/client/configuration/rest'

module MDOT
  class Configuration < Common::Client::Configuration::REST
    def base_path
      Settings.mdot.url
    end

    def service_name
      'MDOT'
    end

    def self.base_request_headers
      super.merge('apiKey' => Settings.mdot.api_key)
    end

    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use      :breakers
        faraday.use      Faraday::Response::RaiseError

        faraday.request :json

        faraday.response :betamocks if mock_enabled?
        faraday.response :snakecase, symbolize: false
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      Settings.mdot.mock || false
    end
  end
end
