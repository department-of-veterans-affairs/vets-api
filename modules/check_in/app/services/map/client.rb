# frozen_string_literal: true

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

    private

    ##
    # Create a Faraday connection object that glues the attributes
    # and the middleware stack for making our HTTP requests to the API
    #
    # @return [Faraday::Connection]
    #
    def connection(server_url:)
      Faraday.new(url: server_url) do |conn|
        conn.use :breakers
        conn.response :raise_error, error_prefix: service_name
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
