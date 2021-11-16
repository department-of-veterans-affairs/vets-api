# frozen_string_literal: true

module MebApi
  module DGI
    class Configuration < Common::Client::Configuration::REST
      BASE_URL = Settings.dgi.vets.url.to_s

      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.url_prefix = BASE_URL
          faraday.request :json

          faraday.use      Faraday::Response::RaiseError
          faraday.response :betamocks if mock_enabled?
          faraday.response :snakecase, symbolize: false
          faraday.response :json, content_type: /\bjson/ # ensures only json content types parsed
          faraday.adapter Faraday.default_adapter
        end
      end

      def mock_enabled?
        # subclass to override
        false
      end
    end
  end
end
