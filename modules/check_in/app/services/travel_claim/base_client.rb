# frozen_string_literal: true

module TravelClaim
  ##
  # Base client class for all Travel Claim API interactions.
  #
  # Inherits from Common::Client::Base for circuit breaker protection and common
  # HTTP functionality. Handles environment-specific headers and mock detection.
  #
  class BaseClient < Common::Client::Base
    ##
    # Initializes the base client with Travel Claim API settings.
    #
    def initialize
      @settings = Settings.check_in.travel_reimbursement_api_v2
      super()
    end

    ##
    # Returns the singleton configuration instance for Travel Claim services.
    #
    # @return [TravelClaim::Configuration] The configuration instance
    #
    def config
      TravelClaim::Configuration.instance
    end

    ##
    # Performs HTTP requests using the inherited Common::Client::Base functionality.
    # This method provides circuit breaker protection, logging, and error handling.
    #
    # @param method [Symbol] HTTP method (:get, :post, :put, :delete)
    # @param path [String] Full URL or path for the request
    # @param params [Hash, String] Request body or query parameters
    # @param headers [Hash] Additional request headers
    # @param options [Hash] Additional options for the request
    # @return [Faraday::Response] The HTTP response object
    #
    def perform(method, path, params, headers = nil, options = nil)
      super(method, path, params, headers, options)
    end

    private

    attr_reader :settings

    ##
    # Builds environment-specific subscription key headers for API authentication.
    # Production uses separate E and S subscription keys, while other environments
    # use a single subscription key.
    #
    # @return [Hash] Headers hash with appropriate subscription keys
    #
    def claim_headers
      if Settings.vsp_environment == 'production'
        {
          'Ocp-Apim-Subscription-Key-E' => settings.e_subscription_key,
          'Ocp-Apim-Subscription-Key-S' => settings.s_subscription_key
        }
      else
        { 'Ocp-Apim-Subscription-Key' => settings.subscription_key }
      end
    end

    ##
    # Determines if mock responses should be used for API calls.
    # Checks both configuration setting and feature flag.
    #
    # @return [Boolean] true if mocking is enabled
    #
    def mock_enabled?
      settings.mock || Flipper.enabled?('check_in_experience_mock_enabled')
    end
  end
end
