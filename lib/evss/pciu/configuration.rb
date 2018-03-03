# frozen_string_literal: true

module EVSS
  module PCIU
    class Configuration < EVSS::Configuration
      self.read_timeout = Settings.evss.pciu.timeout || 30

      def base_path
        "#{Settings.evss.url}/wss-pciu-services-web/rest/pciuServices/v1"
      end

      def service_name
        'EVSS/PCIU'
      end

      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options, ssl: ssl_options) do |faraday|
          faraday.use      :breakers
          faraday.use      EVSS::ErrorMiddleware
          faraday.use      Faraday::Response::RaiseError
          faraday.request  :json
          faraday.response :betamocks if mock_enabled?
          faraday.response :snakecase, symbolize: false
          faraday.response :json
          faraday.adapter  Faraday.default_adapter
        end
      end

      def mock_enabled?
        Settings.evss.mock_pciu || false
      end
    end
  end
end
