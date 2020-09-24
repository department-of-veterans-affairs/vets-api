# frozen_string_literal: true

require 'evss/configuration'

module EVSS
  module Letters
    ##
    # HTTP client configuration for the {EVSS::Letters::Service},
    # sets the base path and a service name for breakers and metrics.
    #
    class Configuration < EVSS::Configuration
      self.read_timeout = Settings.evss.letters.timeout || 55

      ##
      # @return [String] Base path for letters URLs.
      #
      def base_path
        "#{Settings.evss.letters.url}/wss-lettergenerator-services-web/rest/letters/v1"
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'EVSS/Letters'
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        Settings.evss.mock_letters || false
      end
    end
  end
end
