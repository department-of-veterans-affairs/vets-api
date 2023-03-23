# frozen_string_literal: true

module DebtManagementCenter
  module VBS
    ##
    # An object responsible for making HTTP calls to the VBS service that relate to DMC
    #
    # @!attribute settings
    #   @return [Config::Options]
    # @!attribute host
    #   @return (see Config::Options#host)
    # @!attribute service_name
    #   @return (see Config::Options#service_name)
    # @!attribute url
    #   @return (see Config::Options#url)
    class Request
      extend Forwardable
      include Common::Client::Concerns::Monitoring

      STATSD_KEY_PREFIX = 'api.vbs.financial_status_report.request'

      attr_reader :settings

      def_delegators :settings, :base_path, :host, :service_name, :url

      ##
      # Builds a DebtManagementCenter::VBS::Request instance
      #
      # @return [DebtManagementCenter::VBS::Request] an instance of this class
      def self.build
        new
      end

      def initialize
        @settings = Settings.mcp.vbs_v2
      end

      ##
      # Make a HTTP POST call to the VBS service in order to submit VHA FSR
      #
      # @param path [String]
      # @param params [Hash]
      #
      # @return [Faraday::Response]
      #
      def post(path, params)
        with_monitoring do
          connection.post(path) do |req|
            req.body = params
          end
        end
      end

      ##
      # Create a connection object that managers the attributes
      # and the middleware stack for making our HTTP requests to VBS
      #
      # @return [Faraday::Connection]
      #
      def connection
        Faraday.new(url:, headers:) do |conn|
          conn.request :json
          conn.use :breakers
          conn.use Faraday::Response::RaiseError
          conn.response :raise_error, error_prefix: service_name
          conn.response :json
          conn.response :betamocks if mock_enabled?
          conn.adapter Faraday.default_adapter
        end
      end

      ##
      # HTTP request headers for the VBS API
      #
      # @return [Hash]
      #
      def headers
        {
          'Host' => host,
          'Content-Type' => 'application/json',
          'apiKey' => settings.api_key
        }
      end

      ##
      # Betamocks enabled status from settings
      #
      # @return [Boolean]
      #
      def mock_enabled?
        settings.mock || false
      end
    end
  end
end
