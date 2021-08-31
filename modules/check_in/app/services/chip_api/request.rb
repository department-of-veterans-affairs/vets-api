# frozen_string_literal: true

##
# Registering middleware needed by Faraday for logging and error reporting
#
Faraday::Middleware.register_middleware(check_in_logging: Middleware::CheckInLogging)
Faraday::Response.register_middleware(check_in_errors: Middleware::Errors)

module ChipApi
  ##
  # An object responsible for making HTTP calls to the Chip API
  #
  # @!attribute settings
  #   @return [Config::Options]
  # @!attribute service_name
  #   @return (see Config::Options#service_name)
  # @!attribute tmp_api_id
  #   @return (see Config::Options#tmp_api_id)
  # @!attribute url
  #   @return (see Config::Options#url)
  class Request
    extend Forwardable
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.check_in.chip_api.request'

    attr_reader :settings

    def_delegators :settings, :service_name, :tmp_api_id, :url

    ##
    # Builds a ChipApi::Request instance
    #
    # @return [ChipApi::Request] an instance of this class
    #
    def self.build
      new
    end

    def initialize
      @settings = Settings.check_in.chip_api
    end

    ##
    # HTTP GET call to the Chip API to retrieve a user's
    # Check-in information for a specific Appointment
    #
    # @param opts [Hash]
    # @return [Faraday::Response]
    #
    def get(opts = {})
      with_monitoring do
        connection.get(opts[:path]) do |req|
          req.headers = headers.merge('Authorization' => "Bearer #{opts[:access_token]}")
        end
      end
    end

    ##
    # Make a HTTP POST call to the Chip API in order to
    # check-in a user for a specific appointment
    #
    # @param opts [Hash]
    # @return [Faraday::Response]
    #
    def post(opts = {})
      with_monitoring do
        connection.post(opts[:path]) do |req|
          prefix = opts[:access_token] ? 'Bearer' : 'Basic'
          suffix = opts[:access_token] || opts[:claims_token]
          req.headers = headers.merge('Authorization' => "#{prefix} #{suffix}")
        end
      end
    end

    ##
    # Create a connection object that manages the attributes
    # and the middleware stack for making our HTTP requests to Chip
    #
    # @return [Faraday::Connection]
    #
    def connection
      Faraday.new(url: url) do |conn|
        conn.request :json
        conn.use :breakers
        conn.response :check_in_errors
        conn.use :check_in_logging
        conn.response :raise_error, error_prefix: service_name
        conn.response :json
        conn.adapter Faraday.default_adapter
      end
    end

    ##
    # HTTP GET headers for the Chip API
    #
    # @return [Hash]
    #
    def headers
      { 'x-apigw-api-id' => tmp_api_id }
    end
  end
end
