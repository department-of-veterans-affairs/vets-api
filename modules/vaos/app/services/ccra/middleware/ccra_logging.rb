# frozen_string_literal: true

module Ccra
  module Middleware
    ##
    # Faraday middleware that logs various semantically relevant attributes needed for debugging and audit purposes
    #
    class CcraLogging < Common::Middleware::BaseLogging
      private

      def config
        @config ||= Ccra::Configuration.instance
      end

      def statsd_key_prefix
        'api.ccra.response'
      end
    end
  end
end

Faraday::Middleware.register_middleware ccra_logging: Ccra::Middleware::CcraLogging
