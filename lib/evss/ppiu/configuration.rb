# frozen_string_literal: true

module EVSS
  module PPIU
    ##
    # HTTP client configuration for the {EVSS::PPIU::Service},
    # sets the base path and a service name for breakers and metrics.
    #
    class Configuration < EVSS::Configuration
      ##
      # @return [String] Base path for PPIU URLs.
      #
      def base_path
        "#{Settings.evss.url}/wss-ppiu-services-web/rest/ppiuServices/v1"
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'EVSS/PPIU'
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        Settings.evss.mock_ppiu || false
      end
    end
  end
end
