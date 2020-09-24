# frozen_string_literal: true

require 'evss/configuration'

module EVSS
  module VSOSearch
    ##
    # HTTP client configuration for the {VSOSearch::Service},
    # sets the base path and a service name for breakers and metrics.
    #
    class Configuration < EVSS::Configuration
      API_VERSION = Settings.evss.versions.common

      ##
      # @return [String] Base path for VSO search URLs.
      #
      def base_path
        "#{Settings.evss.url}/wss-common-services-web-#{API_VERSION}/rest/vsoSearch/#{API_VERSION}/"
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'EVSS/VSOSearch'
      end

      ##
      # HTTP client configuration for the {VSOSearch::Service},
      # sets the base path, a default timeout, and a service name for breakers and metrics.
      #
      def mock_enabled?
        Settings.evss.mock_vso_search || false
      end
    end
  end
end
