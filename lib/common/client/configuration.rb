# frozen_string_literal: true
require 'singleton'

module Common
  module Client
    class Configuration
      include Singleton

      OPEN_TIMEOUT = 15
      READ_TIMEOUT = 15
      REQUEST_TYPES = %i(get put post delete).freeze
      USER_AGENT = 'Vets.gov Agent'
      BASE_REQUEST_HEADERS = {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'User-Agent' => USER_AGENT
      }.freeze

      def initialize
        # verify that these are implemented
        base_path
        service_name
      end

      def base_path
        raise NotImplementedError, 'Subclass of Configuration must implement base_path'
      end

      def service_name
        raise NotImplementedError, 'Subclass of Configuration must implement service_name'
      end

      def open_timeout
        OPEN_TIMEOUT
      end

      def read_timeout
        READ_TIMEOUT
      end

      def request_types
        REQUEST_TYPES
      end

      def base_request_headers
        BASE_REQUEST_HEADERS
      end

      def request_options
        {
          open_timeout: open_timeout,
          timeout: read_timeout
        }
      end

      def breakers_service
        return @service if defined?(@service)

        path = URI.parse(base_path).path
        host = URI.parse(base_path).host
        matcher = proc do |request_env|
          request_env.url.host == host && request_env.url.path =~ /^#{path}/
        end

        exception_handler = proc do |exception|
          if exception.is_a?(Common::Exceptions::BackendServiceException)
            (500..599).cover?(exception.response_values[:status])
          else
            false
          end
        end

        @service = Breakers::Service.new(
          name: service_name,
          request_matcher: matcher,
          exception_handler: exception_handler
        )
      end
    end
  end
end
