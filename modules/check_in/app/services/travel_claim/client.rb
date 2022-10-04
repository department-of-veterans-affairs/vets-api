# frozen_string_literal: true

module TravelClaim
  ##
  # A service client for handling HTTP requests to the Travel Reimbursement API.
  #
  class Client
    extend Forwardable
    include SentryLogging

    GRANT_TYPE = 'client_credentials'

    attr_reader :settings, :check_in

    def_delegators :settings, :auth_url, :tenant_id, :client_id, :client_secret, :scope, :service_name

    ##
    # Builds a Client instance
    #
    # @param opts [Hash] options to create a Client
    # @option opts [CheckIn::V2::Session] :check_in the check_in session object
    #
    # @return [TravelClaim::Client] an instance of this class
    #
    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts)
      @settings = Settings.check_in.travel_reimbursement_api
      @check_in = opts[:check_in]
    end

    ##
    # HTTP POST call to the VEIS Auth endpoint to get the access token
    #
    # @return [Faraday::Response]
    #
    def token
      connection.post("/#{tenant_id}/oauth2/v2.0/token") do |req|
        req.headers = default_headers
        req.body = URI.encode_www_form(auth_params)
      end
    rescue => e
      log_message_to_sentry(e.original_body, :error,
                            { uuid: check_in.uuid },
                            { external_service: service_name, team: 'check-in' })
      raise e
    end

    private

    ##
    # Create a Faraday connection object that glues the attributes
    # and the middleware stack for making our HTTP requests to the API
    #
    # @return [Faraday::Connection]
    #
    def connection
      Faraday.new(url: auth_url) do |conn|
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

    def auth_params
      {
        client_id: client_id,
        client_secret: client_secret,
        scope: scope,
        grant_type: GRANT_TYPE
      }
    end

    def mock_enabled?
      settings.mock || Flipper.enabled?('check_in_experience_mock_enabled') || false
    end
  end
end
