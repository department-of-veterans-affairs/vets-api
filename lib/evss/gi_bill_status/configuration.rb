# frozen_string_literal: true

require 'evss/configuration'

module EVSS
  module GiBillStatus
    ##
    # HTTP client configuration for the {GiBillStatus::Service},
    # sets the base path and a service name for breakers and metrics.
    #
    class Configuration < EVSS::Configuration
      ##
      # @return [String] Base path for dependents URLs.
      #
      def base_path
        "#{Settings.evss.url}/wss-education-services-web/rest/education/chapter33/v1"
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'EVSS/GiBillStatus'
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        Settings.evss.mock_gi_bill_status || false
      end
    end
  end
end
