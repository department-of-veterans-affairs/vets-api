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

      def self.configuration(configuration = nil)
        @configuration ||= configuration.instance
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
        sanitize_headers!(method, path, params, headers)
        raise_not_authenticated if headers.keys.include?('Token') && headers['Token'].nil?
        connection.send(method.to_sym, path, params) { |request| request.headers.update(headers) }.env
      rescue Common::Exceptions::BackendServiceException => e
        # convert BackendServiceException into a more meaningful exception title for Sentry
        raise config.service_exception.new(
          e.key, e.response_values, e.original_status, e.original_body
        )
      rescue Timeout::Error, Faraday::TimeoutError
        Raven.extra_context(service_name: config.service_name, url: config.base_path)
        raise Common::Exceptions::GatewayTimeout
      rescue Faraday::ClientError => e
        error_class = case e
                      when Faraday::ParsingError
                        Common::Client::Errors::ParsingError
                      else
                        Common::Client::Errors::ClientError
                      end

        response_hash = e.response&.to_hash
        client_error = error_class.new(e.message, response_hash&.dig(:status), response_hash&.dig(:body))
        raise client_error
      end

      def sanitize_headers!(method, path, params, headers)
        unmodified_headers = headers.dup
        headers.transform_keys!(&:to_s)

        headers.transform_values! do |value|
          if value.nil?
            unless Rails.env.test?
              log_message_to_sentry(
                'nil headers bug',
                :info,
                unmodified_headers: unmodified_headers, method: method, path: path, params: params, client: inspect,
                profile: 'pciu_profile'
              )
            end

            ''
          else
            value
          end
        end
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
