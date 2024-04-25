# frozen_string_literal: true

module CheckIn
  module Facilities
    ##
    # A service client for handling HTTP requests to Faclities API.
    #
    class Client
      extend Forwardable
      include SentryLogging

      attr_reader :settings

      def_delegators :settings

      ##
      # Builds a Client instance
      #
      # @param opts [Hash] options to create a Client
      #
      # @return [Map::Client] an instance of this class
      #
      def self.build
        new
      end

      def initialize
        @settings = Settings.check_in.vaos
      end

      ##
      # HTTP GET call to get the facilities data
      #
      # @return [Faraday::Response]
      #
      def facilities(facility_id:)
        connection.get("/facilities/v2/facilities/#{facility_id}")
      end

      private

      ##
      # Create a Faraday connection object that glues the attributes
      # and the middleware stack for making our HTTP requests to the API
      #
      # @return [Faraday::Connection]
      #
      def connection
        Faraday.new('https://veteran.apps.va.gov') do |conn|
          conn.use :breakers
          conn.response :raise_error, error_prefix: 'FACILITIES-API'
          conn.response :betamocks if mock_enabled?

          conn.adapter Faraday.default_adapter
        end
      end

      ##
      # Build a hash of default headers
      #
      # @return [Hash]
      #
      def default_headers
        {
          'Content-Type' => 'application/json'
        }
      end

      def mock_enabled?
        settings.mock || Flipper.enabled?('check_in_experience_mock_enabled') || false
      end
    end
  end
end
