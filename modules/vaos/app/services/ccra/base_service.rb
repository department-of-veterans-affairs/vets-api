# frozen_string_literal: true

module Ccra
  # Ccra::BaseService provides common functionality for making REST API requests
  # to the CCRA service.
  class BaseService < VAOS::SessionService
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.ccra'

    ##
    # Returns the configuration for the CCRA service.
    #
    # @return [CCRA::Configuration] An instance of CCRA::Configuration loaded from settings.
    def config
      @config ||= Configuration.instance
    end

    ##
    # Returns the settings for the CCRA service.
    #
    # @return [Hash] The settings loaded from the VAOS configuration.
    def settings
      @settings ||= Settings.vaos.ccra
    end

    private

    ##
    # Get appropriate headers based on whether mocks are enabled. With Betamocks we
    # bypass the need to request tokens.
    #
    # @return [Hash] Headers for the request or empty hash if mocks are enabled
    def request_headers
      config.mock_enabled? ? {} : headers
    end

    ##
    # Parse response body, handling both string and object responses. With Betamocks we
    # get a string instead of an object.
    #
    # @param response_body [String, Hash] The response body to parse
    # @return [Hash] The parsed response body
    def parse_response_body(response_body)
      response_body.is_a?(String) ? JSON.parse(response_body) : response_body
    end
  end
end
