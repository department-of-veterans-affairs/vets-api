# frozen_string_literal: true

module Vye
  module DGIB
    class Configuration < Common::Client::Configuration::REST
      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use :breakers
          faraday.request :json
          faraday.use      Faraday::Response::RaiseError
          faraday.response :betamocks if mock_enabled?
          faraday.response :snakecase, symbolize: false
          faraday.response :json, content_type: /\bjson/ # ensures only json content types parsed
          faraday.adapter Faraday.default_adapter
        end
      end

      def base_path
        Settings.dgi.vye.vets.url.to_s
      end

      def service_name
        'DGI'
      end

      def mock_enabled?
        Settings.dgi.vye.vets.mock
      end
    end
  end
end
