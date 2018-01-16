# frozen_string_literal: true
module EVSS
  module ReferenceData
    class Configuration < EVSS::Configuration
      PROXY_OPTS = {
        proxy: {
          uri:  URI.parse(Settings.faraday_socks_proxy.uri),
          socks: Settings.faraday_socks_proxy.enabled
        }
      }.freeze

      def base_path
        # TODO: integrate with Settings.yml & devops
        'https://internal-staging-services-1341723990.us-gov-west-1.elb.amazonaws.com/api/refdata/v1'
      end

      def service_name
        'EVSS/ReferenceData'
      end

      def mock_enabled?
        # TODO: create mock data
        false
      end

      def client_cert
        # TODO : implement
        nil
      end

      def client_key
        # TODO : implement
        nil
      end

      def root_ca
        # TODO : implement
        nil
      end

      def connection
        req_options = Settings.faraday_socks_proxy.enabled ? request_options.merge(PROXY_OPTS) : request_options
        @conn ||= Faraday.new(base_path, request: req_options, ssl: ssl_options) do |faraday|
          faraday.use      :breakers
          faraday.use      EVSS::ErrorMiddleware
          faraday.use      Faraday::Response::RaiseError
          faraday.response :betamocks if mock_enabled?
          faraday.response :snakecase, symbolize: false
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
