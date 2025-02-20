# frozen_string_literal: true

require 'lighthouse/configuration'

module Lighthouse
  module Letters
    ##
    # HTTP client configuration for the {Lighthouse::Letters::Service},
    # sets the base path and a service name for breakers and metrics.
    #
    class Configuration < Lighthouse::Configuration
      self.read_timeout = Settings.lighthouse.letters.timeout || 55

      ##
      # @return [String] Base path for letters URLs.
      #
      def base_path
        "#{Settings.lighthouse.letters.url}/wss-lettergenerator-services-web/rest/letters/v1"
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'Lighthouse/Letters'
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        Settings.lighthouse.mock_letters || false
      end
    end
  end
end
