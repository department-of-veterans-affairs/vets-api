# frozen_string_literal: true

require 'common/client/configuration/rest'

module Search
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = 30

    def connection
      @conn ||= Faraday.new(search_url, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use      :breakers
        faraday.use      Faraday::Response::RaiseError

        faraday.response :betamocks if mock_enabled?
        faraday.response :snakecase, symbolize: false
        faraday.response :json, content_type: /\bjson/ # ensures only json content types parsed
        faraday.adapter Faraday.default_adapter
      end
    end

    # Useful for local development testing, see docs/setup/betamocks.md for more info
    def mock_enabled?
      false
    end

    def search_url
      Flipper.enabled?(:use_updated_search_api_endpoint) ? Settings.search_gsa.url : Settings.search.url
    end

    def service_name
      'Search/Results'
    end
  end
end
