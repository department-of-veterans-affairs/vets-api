# frozen_string_literal: true

module Ccra
  # Ccra::BaseService provides common functionality for making REST API requests
  # to the CCRA service.
  class BaseService < VAOS::SessionService
    include Common::Client::Concerns::Monitoring
    include TokenAuthentication

    STATSD_KEY_PREFIX = 'api.ccra'
    REDIS_TOKEN_KEY = REDIS_CONFIG[:ccra_access_token][:namespace]
    REDIS_TOKEN_TTL = REDIS_CONFIG[:ccra_access_token][:each_ttl]

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
  end
end
