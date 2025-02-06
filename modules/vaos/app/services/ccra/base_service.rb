# frozen_string_literal: true

module CCRA
  # CCRA::BaseService provides common functionality for making REST API requests
  # to the CCRA service. It includes monitoring, configuration retrieval, and
  # common headers for requests.
  class BaseService < VAOS::SessionService
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.ccra'

    ##
    # Returns a hash of common headers for CCRA requests.
    #
    # @return [Hash] The headers including Authorization, Content-Type, and X-Request-ID.
    def headers
      {
        'Content-Type' => 'application/json',
        'X-Request-ID' => RequestStore.store['request_id']
      }
    end

    ##
    # Returns the configuration for the CCRA service.
    #
    # @return [CCRA::Configuration] An instance of CCRA::Configuration loaded from settings.
    def config
      @config ||= CCRA::Configuration.instance
    end
  end
end
