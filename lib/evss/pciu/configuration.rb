# frozen_string_literal: true

module EVSS
  module PCIU
    ##
    # HTTP client configuration for the {EVSS::PCIU::Service},
    # sets the base path and a service name for breakers and metrics.
    #
    class Configuration < EVSS::Configuration
      self.read_timeout = Settings.evss.pciu.timeout || 30

      ##
      # @return [String] Base path for PCIU URLs.
      #
      def base_path
        "#{Settings.evss.url}/wss-pciu-services-web/rest/pciuServices/v1"
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'EVSS/PCIU'
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        Settings.evss.mock_pciu || false
      end
    end
  end
end
