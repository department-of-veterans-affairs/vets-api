# frozen_string_literal: true

require 'evss/configuration'

module EVSS
  module IntentToFile
    ##  # TODO - see if we can remove
    # HTTP client configuration for the {IntentToFile::Service},
    # sets the base path and a service name for breakers and metrics.
    #
    class Configuration < EVSS::Configuration
      ##
      # @return [String] Base path for intent to file URLs.
      #
      def base_path
        "#{Settings.evss.url}/wss-intenttofile-services-web/rest/intenttofile/v1"
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'EVSS/IntentToFile'
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        Settings.evss.mock_itf || false
      end
    end
  end
end
