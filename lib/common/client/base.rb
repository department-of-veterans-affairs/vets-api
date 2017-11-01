# frozen_string_literal: true
require 'faraday'
require 'common/client/errors'
require 'common/models/collection'
require 'sentry_logging'

module Common
  module Client
    class SecurityError < StandardError
    end

    class Base
      include SentryLogging

      class << self
        def configuration(configuration = nil)
          @configuration ||= configuration.instance
        end
      end

      private

      def config
        self.class.configuration
      end

      # memoize the connection from config
      def connection
        @connection ||= lambda do
          connection = config.connection
          handlers = connection.builder.handlers

          if handlers.include?(Faraday::Adapter::HTTPClient) &&
             !handlers.include?(Common::Client::Middleware::Request::RemoveCookies)
            raise SecurityError, 'http client needs cookies stripped'
          end

          connection
        end.call
      end

      def perform(method, path, params, headers = nil)
        raise NoMethodError, "#{method} not implemented" unless config.request_types.include?(method)

        send(method, path, params || {}, headers || {})
      end

      def request(method, path, params = {}, headers = {})
        raise_not_authenticated if headers.keys.include?('Token') && headers['Token'].nil?
        connection.send(method.to_sym, path, params) { |request| request.headers.update(headers) }.env
      rescue Timeout::Error, Faraday::TimeoutError
        log_message_to_sentry(
          "Timeout while connecting to #{config.service_name} service", :error, extra_context: { url: config.base_path }
        )
        raise Common::Exceptions::GatewayTimeout
      rescue Faraday::ParsingError => e
        # Faraday::ParsingError is a Faraday::ClientError but should be handled by implementing service
        raise e
      rescue Faraday::ClientError => e
        client_error = Common::Client::Errors::ClientError.new(
          e.message,
          e.response&.dig(:status),
          e.response&.dig(:body)
        )
        raise client_error
      end

      def get(path, params, headers = base_headers)
        request(:get, path, params, headers)
      end

      def post(path, params, headers = base_headers)
        request(:post, path, params, headers)
      end

      def put(path, params, headers = base_headers)
        request(:put, path, params, headers)
      end

      def delete(path, params, headers = base_headers)
        request(:delete, path, params, headers)
      end

      def raise_not_authenticated
        raise Common::Client::Errors::NotAuthenticated, 'Not Authenticated'
      end
    end
  end
end
