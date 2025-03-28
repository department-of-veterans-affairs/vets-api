# frozen_string_literal: true

module Eps
  module Middleware
    ##
    # Faraday middleware that logs various semantically relevant attributes needed for debugging and audit purposes
    #
    class EpsLogging < Common::Middleware::BaseLogging
      private

      # Returns the configuration for the EPS service.
      # @return [Eps::Configuration] the EPS configuration instance.
      def config
        @config ||= Eps::Configuration.instance
      end

      # Returns the StatsD key prefix for EPS.
      # @return [String] the StatsD key prefix.
      def statsd_key_prefix
        'api.eps.response'
      end
    end
  end
end

Faraday::Middleware.register_middleware eps_logging: Eps::Middleware::EpsLogging
