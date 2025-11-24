# frozen_string_literal: true

module SOB
  module DGIB
    class Configuration < ::Common::Client::Configuration::REST
      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use(:breakers, service_name:)
          faraday.response :raise_custom_error, error_prefix: service_name
          faraday.response :betamocks if mock_enabled?
          faraday.response :snakecase, symbolize: false
          faraday.response :json, content_type: /\bjson/
          faraday.adapter Faraday.default_adapter
        end
      end

      def service_name
        'SOB/DGIB'
      end

      def base_path
        Settings.dgi.sob.claimants.url
      end

      def mock_enabled?
        Settings.dgi.sob.claimants.mock || false
      end
    end
  end
end
