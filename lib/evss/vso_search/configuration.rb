# frozen_string_literal: true

module EVSS
  module VsoSearch
    ##
    # HTTP client configuration for the {VsoSearch::Service},
    # sets the base path and a service name for breakers and metrics.
    #
    class Configuration < EVSS::Configuration
      API_VERSION = Settings.evss.versions.common

      ##
      # @return [String] Base path for VSO search URLs.
      #
      def base_path
        "#{Settings.evss.url}/wss-common-services-web-#{API_VERSION}/rest/vsoSearch/11.6/"
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'EVSS/VsoSearch'
      end

      ##
      # HTTP client configuration for the {VsoSearch::Service},
      # sets the base path, a default timeout, and a service name for breakers and metrics.
      #
      def mock_enabled?
        Settings.evss.mock_vso_search || false
      end
    end
  end
end
