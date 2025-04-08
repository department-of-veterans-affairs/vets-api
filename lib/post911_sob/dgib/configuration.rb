# frozen_string_literal: true

require 'common/client/configuration/rest'

module Post911SOB
  module DGIB
    class Configuration < Common::Client::Configuration::REST
      SETTINGS = Settings.dgi.post911_sob.claimants

      # TO-DO: Datadog

      def base_path
        SETTINGS.url.to_s
      end

      def service_name
        'Post911SOB/DGIB'
      end

      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use(:breakers, service_name:)
          faraday.use Faraday::Response::RaiseError
          faraday.request :json

          faraday.response :betamocks if mock_enabled?
          faraday.response :snakecase, symbolize: false
          faraday.response :json, content_type: /\bjson/ # ensures only json content types parsed
          faraday.adapter Faraday.default_adapter
        end
      end

      private

      def mock_enabled?
        SETTINGS.mock || false
      end
    end
  end
end
