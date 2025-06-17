# frozen_string_literal: true

require 'common/client/configuration/rest'

module BID
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
      # subclass to override
      false
    end
  end
end
