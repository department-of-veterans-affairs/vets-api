# frozen_string_literal: true

require 'evss/configuration'

module EVSS
  module PCIUAddress
    ##
    # HTTP client configuration for the {EVSS::PCIUAddress::Service},
    # sets the base path and a service name for breakers and metrics.
    #
    class Configuration < EVSS::Configuration
      self.read_timeout = Settings.evss.pciu_address.timeout || 30

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
        'EVSS/PCIUAddress'
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        Settings.evss.mock_pciu_address || false
      end
    end
  end
end
