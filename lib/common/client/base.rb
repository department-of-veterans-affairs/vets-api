# frozen_string_literal: true

require 'faraday'
require 'common/client/errors'
require 'common/models/collection'
require 'sentry_logging'

module Common
  module Client
    ##
    # Raised if the Faraday adapter is a Faraday::Adapter::HTTPClient and the
    # Common::Client::Middleware::Request::RemoveCookies middleware in not included.
    #
    class SecurityError < StandardError
    end

    ##
    # Raised when the breakers Faraday middleware is not first in the stack.
    #
    class BreakersImplementationError < StandardError
    end

    ##
    # Base class for creating HTTP services. Wraps the Faraday gem and is configured via by passing in a
    # {Common::Client::Configuration::REST} or {Common::Client::Configuration::SOAP} depending on the type
    # of service you're connecting to. Once configured requests are made via the `perform` method.
    #
    # @example Create a service and make a GET request
    #   class MyService < Common::Client::Base
    #     configuration MyConfiguration
    #
    #     def get_resource
    #       perform(:get, '/api/v1/resource')
    #     end
    #   end
    #
    #   service = MyService.new
    #   response = service.get_resource
    #
    # @example a POST request with a body, headers, and Faraday options
    #   def post_resource(json)
    #     headers = { 'Content-Type' => 'application/json' }
    #     options = { timeout: 60 }
    #     response = perform(:post, '/submit', json, headers, options)
    #   end
    #
    class Base
      include SentryLogging

      ##
      # Sets the configuration singleton to use
      #
      def self.configuration(configuration = nil)
        @configuration ||= configuration.instance
      end

      def raise_backend_exception(key, source, error = nil)
        raise Common::Exceptions::BackendServiceException.new(
          key,
          { source: source.to_s },
          error&.status,
          error&.body
        )
      end

      private

      def config
        self.class.configuration
      end

      def service_name
        config.service_name
      end

      def connection
        @connection ||= lambda do
          connection = config.connection
          handlers = connection.builder.handlers
          adapter = connection.builder.adapter

          if adapter == Faraday::Adapter::HTTPClient &&
             handlers.exclude?(Common::Client::Middleware::Request::RemoveCookies)
            raise SecurityError, 'http client needs cookies stripped'
          end

          if handlers.include?(Breakers::UptimeMiddleware)
            if handlers.first == Breakers::UptimeMiddleware
              message = "Please pass a service_name argument to the Breakers middleware for service: #{service_name}"
              warn(message) unless connection.app.service_name
              return connection
            end

            raise BreakersImplementationError, 'Breakers should be the first middleware implemented.'
          else
            warn("Breakers is not implemented for service: #{service_name}")
          end

          connection
        end.call
      end

      def perform(method, path, params, headers = nil, options = nil)
        raise NoMethodError, "#{method} not implemented" unless config.request_types.include?(method)

        send(method, path, params || {}, headers || {}, options || {})
      end

      def request(method, path, params = {}, headers = {}, options = {}) # rubocop:disable Metrics/MethodLength
        Datadog::Tracing.active_span&.set_tag('common_client_service', service_name)
        sanitize_headers!(method, path, params, headers)
        raise_not_authenticated if headers.keys.include?('Token') && headers['Token'].nil?
        connection.send(method.to_sym, path, params) do |request|
          request.headers.update(headers)
          options.each { |option, value| request.options.send("#{option}=", value) }
        end.env
      rescue Common::Exceptions::BackendServiceException => e
        # Raise a Breakers-trackable error first (ClientError)
        begin
          raise Common::Client::Errors::ClientError.new(
            e.message,
            e.original_status,
            e.original_body,
            headers: { 'x-code' => e.key } # optional
          )
        rescue Common::Client::Errors::ClientError
          # Immediately re-raise the original service-specific exception
          raise config.service_exception.new(
            e.key, e.response_values, e.original_status, e.original_body
          )
        end
      rescue Timeout::Error, Faraday::TimeoutError => e
        Sentry.set_extras(service_name:, url: path)
        raise Common::Exceptions::GatewayTimeout, e.class.name
      rescue Faraday::ClientError, Faraday::ServerError, Faraday::Error => e
        error_class = case e
                      when Faraday::ParsingError
                        Common::Client::Errors::ParsingError
                      else
                        Common::Client::Errors::ClientError
                      end

        response_hash = e.response&.to_hash
        client_error = error_class.new(e.message, response_hash&.dig(:status), response_hash&.dig(:body),
                                       headers: response_hash&.dig(:headers))
        raise client_error
      end

      def sanitize_headers!(_method, _path, _params, headers)
        headers.transform_keys!(&:to_s)

        headers.transform_values! do |value|
          if value.nil?
            ''
          else
            value
          end
        end
      end

      def get(path, params, headers, options)
        request(:get, path, params, headers, options)
      end

      def post(path, params, headers, options)
        request(:post, path, params, headers, options)
      end

      def put(path, params, headers, options)
        request(:put, path, params, headers, options)
      end

      def delete(path, params, headers, options)
        request(:delete, path, params, headers, options)
      end

      def raise_not_authenticated
        raise Common::Client::Errors::NotAuthenticated, 'Not Authenticated'
      end
    end
  end
end
