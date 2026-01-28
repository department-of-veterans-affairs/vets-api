# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/snakecase'
require 'vass/response_middleware'

module Vass
  ##
  # Configuration class for VASS API clients.
  #
  # Singleton class providing Faraday connection setup with circuit breaker integration
  # and mock response support.
  #
  class Configuration < Common::Client::Configuration::REST
    include Singleton

    # Override default timeouts to handle external VASS API calls
    self.open_timeout = 30  # Connection establishment timeout
    self.read_timeout = 30  # Response timeout for external API calls

    ##
    # Returns the base URL for VASS API requests.
    #
    # @return [String] The base URL for API requests
    #
    def base_path
      Settings.vass.api_url
    end

    ##
    # Returns the service name for circuit breaker and logging purposes.
    #
    # @return [String] The service name identifier
    #
    def service_name
      Settings.vass.service_name
    end

    ##
    # Creates and configures a Faraday connection with the complete middleware stack.
    # The connection is memoized per server_url to avoid recreating connections
    # for the same endpoint. The connection includes:
    # - Circuit breaker middleware for fault tolerance
    # - JSON request/response processing
    # - Custom error handling with service-specific prefixes
    # - Mock response support for testing environments
    #
    # @param server_url [String] The base URL for the connection (defaults to base_path)
    # @return [Faraday::Connection] Configured HTTP connection (memoized per server_url)
    #
    def connection(server_url: base_path)
      @__conn_pool__ ||= {}
      @__conn_pool__[server_url] ||= Faraday.new(url: server_url, headers: base_request_headers,
                                                 request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :camelcase # Transform outgoing snake_case to camelCase
        conn.request :json
        # Response middleware runs in reverse order (bottom-up):
        # 1. raise_custom_error handles error responses
        # 2. snakecase transforms keys from camelCase to snake_case (with string keys, not symbols)
        # 3. vass_errors checks for HTTP 200 with success: false (must run before snakecase)
        # 4. json_parser parses JSON string to Ruby hash
        # 5. betamocks (if enabled) returns mock responses - positioned last so responses
        #    flow through the full middleware stack, mimicking real API calls
        conn.response :raise_custom_error, error_prefix: service_name, include_request: true
        conn.response :snakecase, symbolize: false
        conn.response :vass_errors
        conn.response :json_parser
        conn.response :betamocks if mock_enabled?
        conn.adapter Faraday.default_adapter
      end
    end

    private

    ##
    # Determines if mock responses should be enabled for API calls.
    # Checks both configuration setting and feature flag.
    #
    # @return [Boolean] true if mocking is enabled
    #
    def mock_enabled?
      Settings.vass.mock || Flipper.enabled?('vass_api_mock_enabled')
    end
  end
end
