# frozen_string_literal: true

require 'common/client/configuration/rest'

module Search
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = 30

    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use      :breakers
        faraday.use      Faraday::Response::RaiseError

        faraday.response :betamocks if mock_enabled?
        faraday.response :snakecase, symbolize: false
        faraday.response :json, content_type: /\bjson/ # ensures only json content types parsed
        faraday.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      Settings.search.mock_search || false
    end

    def base_path
      "#{Settings.search.url}/search/i14y"
    end

    def service_name
      'Search/Results'
    end
  end
end
