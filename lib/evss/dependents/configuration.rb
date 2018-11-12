# frozen_string_literal: true

module EVSS
  module Dependents
    class Configuration < EVSS::Configuration
      def base_path
        "#{Settings.evss.url}/wss-686-services-web-2.6/rest/"
      end

      def service_name
        'EVSS/Dependents'
      end

      def connection
        @conn ||= Faraday.new(base_path, request: request_options, ssl: ssl_options) do |faraday|
          faraday.use      :breakers
          faraday.use      EVSS::ErrorMiddleware
          faraday.use      Faraday::Response::RaiseError
          faraday.response :betamocks if mock_enabled?
          # calls to EVSS returns non JSON responses for some scenarios that don't make it through VAAFI
          # content_type: /\bjson$/ ensures only json content types are attempted to be parsed.
          faraday.response :json, content_type: /\bjson$/
          faraday.use :immutable_headers
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
