# frozen_string_literal: true

module EVSS
  module AWS
    class Configuration < Common::Client::Configuration::REST
      extend Memoist

      def service_name
        raise NotImplementedError, "Subclass #{self.class.name} of Configuration must implement service_name"
      end

      def mock_enabled?
        # subclass to override
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

      def ssl_options
        { verify: false }
        # TODO: is SSL enabled for EVSS in AWS?
      end

      def connection
        req_options = Settings.faraday_socks_proxy.enabled ? request_options.merge(proxy_options) : request_options
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

      protected

      def proxy_options
        {
          proxy: {
            uri:  URI.parse(Settings.faraday_socks_proxy.uri),
            socks: Settings.faraday_socks_proxy.enabled
          }
        }
      end
      memoize :proxy_options
    end
  end
end
