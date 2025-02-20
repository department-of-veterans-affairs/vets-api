# frozen_string_literal: true

require 'lighthouse/configuration'

module Lighthouse
  module PCIU
    ##
    # HTTP client configuration for the {Lighthouse::PCIU::Service},
    # sets the base path and a service name for breakers and metrics.
    #
    class Configuration < Lighthouse::Configuration
      self.read_timeout = Settings.lighthouse.pciu.timeout || 30

      ##
      # @return [String] Base path for PCIU URLs.
      #
      def base_path
        "#{Settings.lighthouse.url}/wss-pciu-services-web/rest/pciuServices/v1"
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'Lighthouse/PCIU'
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        Settings.lighthouse.mock_pciu || false
      end
    end
  end
end
