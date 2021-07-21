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
  class Request
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.check_in.chip_api.request'
    ##
    # Builds a ChipApi::Request instance
    #
    # @return [ChipApi::Request] an instance of this class
    #
    def self.build
      new
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
        conn.response :check_in_errors
        conn.use :check_in_logging
        conn.adapter Faraday.default_adapter
      end
    end

    ##
    # HTTP GET headers for the Chip API
    #
    # @return [Hash]
    #
    def headers
      { 'x-apigw-api-id' => chip_api.tmp_api_id }
    end

    ##
    # Helper method for returning the Chip URL
    # from our environment configuration file
    #
    # @return [String]
    #
    def url # rubocop:disable Rails/Delegate
      chip_api.url
    end

    private

    def chip_api
      Settings.check_in.chip_api
    end
  end
end
