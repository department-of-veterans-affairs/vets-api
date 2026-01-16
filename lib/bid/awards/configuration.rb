# frozen_string_literal: true

require 'bid/configuration'

# module for BID service
module BID
  # Awards module containing configuration and service classes for BID Awards functionality
  module Awards
    # Configuration class for BID Awards service
    # Extends the base BID::Configuration with awards-specific settings
    class Configuration < BID::Configuration
      # Returns the base path for the BID Awards API
      # @return [String] the base URL path for awards API endpoints
      def base_path
        "#{Settings.bid.awards.base_url}/api/v1/awards/"
      end

      # Returns the service name for logging and monitoring
      # @return [String] the service name identifier
      def service_name
        'BID/Awards'
      end

      # Constructs the request headers for API calls
      # @return [Hash] headers hash including authorization token
      def request_headers
        {
          Authorization: "Bearer #{Settings.bid.awards.credentials}"
        }
      end

      # Checks if mock mode is enabled for the BID Awards service
      # @return [Boolean] true if mocking is enabled, false otherwise
      def mock_enabled?
        Settings.bid.awards.mock || false
      end
    end
  end
end
