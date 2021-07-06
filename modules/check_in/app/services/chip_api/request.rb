# frozen_string_literal: true

Faraday::Response.register_middleware check_in_errors: HealthQuest::Middleware::Response::Errors
Faraday::Middleware.register_middleware check_in_logging: HealthQuest::Middleware::HealthQuestLogging

module ChipApi
  ##
  # An object responsible for making HTTP calls to the Chip API
  #
  class Request
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
    # @param lorota_uuid [String]
    # @return [Faraday::Response]
    #
    def get(lorota_uuid)
      connection.get("/appointments/#{lorota_uuid}") do |req|
        req.headers = get_headers
      end
    end

    ##
    # make a HTTP POST call to the Chip API in order to
    # check-in a user for a specific appointment
    #
    # @param params [String] URI.encode_www_form parameters
    # @return [Faraday::Response]
    #
    def post(check_in_params)
      connection.post('/actions/check-in') { |req| req.body = check_in_params }
    end

    private

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
    def get_headers
      { 'Accept' => '*/*' }
    end

    ##
    # Helper method for returning the Chip URL
    # from our environment configuration file
    #
    # @return [String]
    #
    def url
      Settings.check_in.chip_api.url
    end
  end
end
