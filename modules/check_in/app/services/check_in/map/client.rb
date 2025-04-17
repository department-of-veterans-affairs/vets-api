# frozen_string_literal: true

module CheckIn
  module Map
    ##
    # A service client for handling HTTP requests to MAP API.
    #
    class Client
      extend Forwardable
      include SentryLogging

      attr_reader :settings

      def_delegators :settings, :service_name, :url

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
        @settings = Settings.check_in.map_api
      end

      def deep_analyze_and_modify(obj)
        case obj
        when Hash
          obj.each do |key, value|
            if key == :system && value.is_a?(String)
              obj[key] = value.gsub('https://va.gov', '')
            else
              deep_analyze_and_modify(value)
            end
          end
        when Array
          obj.each do |value|
            deep_analyze_and_modify(value)
          end
        end
      end

      ##
      # HTTP GET call to get the appointment data from MAP
      #
      # @return [Faraday::Response]
      #
      def appointments(token:, patient_icn:, query_params:)
        response = connection.post("/vaos/v1/patients/#{patient_icn}/appointments?#{query_params}") do |req|
          req.headers = default_headers.merge('X-VAMF-JWT' => token)
        end
        deep_analyze_and_modify(response)
        response
      rescue => e
        if e.respond_to?(:original_body) && e.respond_to?(:original_status)
          Faraday::Response.new(body: e.original_body, status: e.original_status)
        else
          raise e
        end
      end

      private

      ##
      # Create a Faraday connection object that glues the attributes
      # and the middleware stack for making our HTTP requests to the API
      #
      # @return [Faraday::Connection]
      #
      def connection
        Faraday.new(url:) do |conn|
          conn.use(:breakers, service_name:)
          conn.response :raise_custom_error, error_prefix: service_name
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
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      end

      def mock_enabled?
        settings.mock || Flipper.enabled?('check_in_experience_mock_enabled') || false
      end
    end
  end
end
