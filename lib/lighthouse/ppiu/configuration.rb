# frozen_string_literal: true

require 'lighthouse/configuration'

module Lighthouse
  module PPIU
    ##
    # HTTP client configuration for the {Lighthouse::PPIU::Service},
    # sets the base path and a service name for breakers and metrics.
    #
    class Configuration < Lighthouse::Configuration
      self.read_timeout = Settings.lighthouse.ppiu.timeout || 30
      ##
      # @return [String] Base path for PPIU URLs.
      #
      def base_path
        "#{Settings.lighthouse.url}/wss-ppiu-services-web/rest/ppiuServices/v1"
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'Lighthouse/PPIU'
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        Settings.lighthouse.mock_ppiu || false
      end
    end
  end
end
