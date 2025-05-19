# frozen_string_literal: true

require 'common/client/configuration/rest'

module RES
  class Configuration < Common::Client::Configuration::REST
    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use Faraday::Response::RaiseError
        faraday.response :betamocks if mock_enabled?
        faraday.response :snakecase, symbolize: false
        faraday.response :json, content_type: /\bjson/
        faraday.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      Settings.res.mock_ch_31 || false
    end

    def base_path
      Settings.res.base_url
    end

    def service_name
      'ReadinessAndEmployementSystem'
    end
  end
end
