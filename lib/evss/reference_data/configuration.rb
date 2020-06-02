# frozen_string_literal: true

module EVSS
  module ReferenceData
    # HTTP client configuration for the {ReferenceData::Service} to
    # set the base path and a service name for breakers and metrics
    #
    class Configuration < EVSS::AWSConfiguration
      ##
      # @return [String] Base path for ReferenceData URLs.
      #
      def base_path
        Settings.evss.aws.url.to_s
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'EVSS/AWS/ReferenceData'
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        # TODO: create mock data
        false
      end

      def self.breakers_service
        BaseService.create_breakers_service(name: service_name, url: base_path)
      end
    end
  end
end
