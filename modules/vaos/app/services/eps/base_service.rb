# frozen_string_literal: true

module Eps
  # Eps::BaseService provides common functionality for making REST API requests
  # to the EPS service.
  class BaseService < VAOS::SessionService
    include Common::Client::Concerns::Monitoring
    include Eps::TokenAuthentication

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
    # Returns the patient ID for the current user.
    #
    # @return [String] The ICN of the current user.
    def patient_id
      @patient_id ||= user.icn
    end
  end
end
