# frozen_string_literal: true

require_relative '../concerns/token_authentication'
require_relative '../concerns/jwt_wrapper'

module Ccra
  # Ccra::BaseService provides common functionality for making REST API requests
  # to the CCRA service. It includes monitoring, configuration retrieval, and
  # common headers for requests.
  class BaseService < VAOS::SessionService
    include Common::Client::Concerns::Monitoring
    include Concerns::TokenAuthentication

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
  end
end
