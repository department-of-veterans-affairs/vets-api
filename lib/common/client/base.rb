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

      def connection
        @connection ||= lambda do
          connection = config.connection
          handlers = connection.builder.handlers

          if handlers.include?(Faraday::Adapter::HTTPClient) &&
             !handlers.include?(Common::Client::Middleware::Request::RemoveCookies)
            raise SecurityError, 'http client needs cookies stripped'
          end

          if handlers.include?(Breakers::UptimeMiddleware)
            return connection if handlers.first == Breakers::UptimeMiddleware

            raise BreakersImplementationError, 'Breakers should be the first middleware implemented.'
          else
            warn("Breakers is not implemented for service: #{config.service_name}")
          end

          connection
        end.call
      end

      def perform(method, path, params, headers = nil, options = nil)
        raise NoMethodError, "#{method} not implemented" unless config.request_types.include?(method)

        send(method, path, params || {}, headers || {}, options || {})
      end

      def request(method, path, params = {}, headers = {}, options = {})
        sanitize_headers!(method, path, params, headers)
        raise_not_authenticated if headers.keys.include?('Token') && headers['Token'].nil?
        connection.send(method.to_sym, path, params) do |request|
          request.headers.update(headers)
          options.each { |option, value| request.options.send("#{option}=", value) }
        end.env
      rescue Common::Exceptions::BackendServiceException => e
        # convert BackendServiceException into a more meaningful exception title for Sentry
        raise config.service_exception.new(e.key, e.response_values, e.original_status, e.original_body)
      rescue Timeout::Error, Faraday::TimeoutError => e
        PersonalInformationLog.create(data: response_hash_from_error(e), error_class: e.class)
        Raven.extra_context(service_name: config.service_name, url: config.base_path)
        raise Common::Exceptions::GatewayTimeout
      rescue Faraday::ClientError => e
        error_class = case e
                      when Faraday::ParsingError
                        Common::Client::Errors::ParsingError
                      else
                        Common::Client::Errors::ClientError
                      end
        raise error_class.new(e.message, response_status_from_error(e), response_body_from_error(e))
      end

      def response_status_from_error(error)
        hash = response_hash_from_error(error)[:response][:hash]
        return nil unless hash.is_a? Hash

        hash[:status]
      end

      def response_body_from_error(error)
        hash = response_hash_from_error(error)[:response][:hash]
        return nil unless hash.is_a? Hash

        hash[:body]
      end

      # response_hash_from_error
      #
      # given an object, returns a hash based off of its .response method:
      #
      #   {
      #     response: {
      #       hash:   hash of object.response (if possible),
      #       object: object.response || nil
      #   }
      #
      # a hash of this shape ^^^ will be returned whether or not an object has a .response
      # method, and whether or not what is returned by .response can be turned into a hash
      #
      # Motivation:
      #
      # I wanted to be able to reliably extract a response hash from a Faraday object.
      # I noticed we were already using &.to_hash, but I also noticed we are currently
      # using Faraday 0.17.0. --responses in that version don't have a .to_hash method
      # (it wasn't introduced until 1.0.0). Therefore, to be maximally, safe, I try
      # using .to_hash, then [.status, .body, .headers] (availiable in all versions),
      # then .to_h. This also leaves room for us to author our own errors that conform
      # to the structure of Faraday errors.
      #
      # https://www.rubydoc.info/gems/faraday/0.17.0/Faraday/Response
      # https://www.rubydoc.info/gems/faraday/Faraday/Response

      def response_hash_from_error(error)
        response = error.try(:response)

        # lambda that returns a hash of the response and the response itself
        response_hash = ->(hash) { { response: { hash: hash, object: response } } }

        # no response method
        return response_hash[nil] unless error.respond_to?(:response)

        # response has .to_hash (Farady 1.0.0)
        return response_hash[response.to_hash] if response.respond_to?(:to_hash)

        # response does not have .to_hash but has .status, .body, .headers (Faraday < 1.0.0)
        if %i[status body headers].all? { |method| response.respond_to? method }
          return response_hash[{ status: response.status, body: response.body, headers: response.headers }]
        end

        # last ditch to get a hash
        response_hash[response.try(:to_h)]
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
