# frozen_string_literal: true

require 'common/client/configuration/rest'

module TravelClaim
  ##
  # Configuration class for Travel Claim API clients.
  #
  # Singleton class providing Faraday connection setup with circuit breaker integration
  # and mock response support. Supports dynamic URL switching via server_url accessor.
  #
  class Configuration < Common::Client::Configuration::REST
    include Singleton

    ##
    # @!attribute [w] server_url
    #   @return [String, nil] Custom server URL that overrides the default base_path
    attr_writer :server_url

    ##
    # Returns the base URL for Travel Claim API requests.
    # Uses server_url if set, otherwise defaults to the configured claims URL.
    #
    # @return [String] The base URL for API requests
    #
    def base_path
      Settings.check_in.travel_reimbursement_api_v2.claims_url_v2
    end

    ##
    # Returns the service name for circuit breaker and logging purposes.
    #
    # @return [String] The service name identifier
    #
    def service_name
      'TravelClaim'
    end

    ##
    # Returns the supported HTTP request types.
    # Adds PATCH method support for V3 API endpoints.
    #
    # @return [Array<Symbol>] Array of supported HTTP methods
    #
    def request_types
      %i[get post put delete patch]
    end

    ##
    # Creates and configures a Faraday connection with the complete middleware stack.
    # The connection includes:
    # - Circuit breaker middleware for fault tolerance
    # - JSON request/response processing
    # - Custom error handling with service-specific prefixes
    # - Mock response support for testing environments
    #
    # @return [Faraday::Connection] Configured HTTP connection
    #
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :json
        conn.response :json
        conn.response :raise_custom_error, error_prefix: service_name, include_request: true
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
      Settings.check_in.travel_reimbursement_api_v2.mock || Flipper.enabled?('check_in_experience_mock_enabled')
    end
  end
end
