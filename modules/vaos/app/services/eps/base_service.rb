# frozen_string_literal: true

module Eps
  # Eps::BaseService provides common functionality for making REST API requests
  # to the EPS service.
  class BaseService < VAOS::SessionService
    include Common::Client::Concerns::Monitoring
    include TokenAuthentication

    STATSD_KEY_PREFIX = 'api.eps'
    REDIS_TOKEN_KEY = REDIS_CONFIG[:eps_access_token][:namespace]
    REDIS_TOKEN_TTL = REDIS_CONFIG[:eps_access_token][:each_ttl]

    ##
    # Returns the configuration for the EPS service.
    #
    # @return [Eps::Configuration] An instance of Eps::Configuration loaded from settings.
    def config
      @config ||= Eps::Configuration.instance
    end

    ##
    # Returns the settings for the EPS service.
    #
    # @return [Hash] The settings loaded from the VAOS configuration.
    def settings
      @settings ||= Settings.vaos.eps
    end

    private

    ##
    # Get appropriate headers based on whether mocks are enabled. With Betamocks we
    # bypass the need to request tokens.
    #
    # @return [Hash] Headers for the request or empty hash if mocks are enabled
    #
    def request_headers
      config.mock_enabled? ? {} : headers
    end

    ##
    # Parse response body, handling both string and object responses. With Betamocks we
    # get a string instead of an object.
    #
    # @param response_body [String, Hash] The response body to parse
    # @return [Hash] The parsed response body with symbolized keys
    def parse_response_body(response_body)
      # Note JSON.parse is only used for betamock responses
      response_body.is_a?(String) ? JSON.parse(response_body, symbolize_names: true) : response_body
    end

    ##
    # Returns the patient ID for the current user.
    #
    # @return [String] The ICN of the current user.
    def patient_id
      @patient_id ||= user.icn
    end
  end
end
