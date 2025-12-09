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

    # Override default timeouts to handle multiple external API calls in travel claims submission
    self.open_timeout = 30  # Connection establishment timeout
    self.read_timeout = 30  # Response timeout for external API calls

    ##
    # @!attribute [w] server_url
    #   @return [String, nil] Custom server URL that overrides the default base_path
    attr_writer :server_url

    ##
    # Returns the base URL for Travel Claim API requests.
    # Combines the base URL with the base path for routing through the forward proxy.
    #
    # @return [String] The base URL for API requests
    #
    def base_path
      url = Settings.check_in.travel_reimbursement_api_v2.claims_url_v2
      path = Settings.check_in.travel_reimbursement_api_v2.claims_base_path_v2
      return url if path.blank?

      "#{url.delete_suffix('/')}/#{path.delete_prefix('/')}"
    end

    ##
    # Returns the service name for circuit breaker and logging purposes.
    #
    # @return [String] The service name identifier
    #
    def service_name
      Settings.check_in.travel_reimbursement_api_v2.service_name
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
