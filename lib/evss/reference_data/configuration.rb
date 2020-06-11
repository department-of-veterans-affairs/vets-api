# frozen_string_literal: true

module EVSS
  module ReferenceData
    # HTTP client configuration for the {ReferenceData::Service} to
    # set the base path and a service name for breakers and metrics
    #
    class Configuration < EVSS::Configuration
      ##
      # @return [String] Base path for ReferenceData URLs.
      #
      def base_path
        "#{Settings.evss.url}/wss-referencedata-services-web/rest/referencedata/v1"
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'EVSS/ReferenceData'
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        # TODO: create mock data
        Settings.evss.mock_reference || false
      end
    end
  end
end
