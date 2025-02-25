# frozen_string_literal: true

module Ccra
  module Middleware
    ##
    # Faraday middleware that logs various semantically relevant attributes needed for debugging and audit purposes
    #
    class CcraLogging < Common::Middleware::BaseLogging
      private

      # Returns the configuration for the CCRA service.
      # @return [Ccra::Configuration] the CCRA configuration instance.
      def config
        @config ||= Ccra::Configuration.instance
      end

      # Returns the StatsD key prefix for CCRA.
      # @return [String] the StatsD key prefix.
      def statsd_key_prefix
        'api.ccra.response'
      end
    end
  end
end

Faraday::Middleware.register_middleware ccra_logging: Ccra::Middleware::CcraLogging
