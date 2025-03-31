# frozen_string_literal: true

module V2
  module Lorota
    ##
    # A service client for handling HTTP requests to LoROTA API. This needs to be instantiated with a
    # {CheckIn::V2::Session} object so that the {ClaimsToken} can be built and passed to LoROTA for
    # authentication on subsequent calls.
    #
    # @see https://github.com/department-of-veterans-affairs/lorota#lorota-security-details LoROTA security details
    #
    # @example
    #   client = Client.build(check_in: check_in)
    #
    # @!attribute [r] claims_token
    #   @return [V2::Lorota::ClaimsToken]
    # @!attribute [r] check_in
    #   @return [CheckIn::V2::Session]
    # @!attribute [r] settings
    #   @return [Config::Options]
    # @!method url
    #   @return (see Config::Options#url)
    # @!method base_path
    #   @return (see Config::Options#base_path)
    # @!method api_id
    #   @return (see Config::Options#api_id)
    # @!method api_key
    #   @return (see Config::Options#api_key)
    # @!method service_name
    #   @return (see Config::Options#service_name)
    class Client
      extend Forwardable

      attr_reader :claims_token, :check_in, :settings

      def_delegators :settings, :url, :base_path, :api_id, :api_key, :service_name

      ##
      # Builds a Client instance
      #
      # @param opts [Hash] options to create a Client
      # @option opts [CheckIn::V2::Session] :check_in the session object
      #
      # @return [V2::Lorota::Client] an instance of this class
      #
      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @settings = Settings.check_in.lorota_v2
        @check_in = opts[:check_in]
        @claims_token = ClaimsToken.build(check_in:).sign_assertion
      end

      # POST request to LoROTA token endpoint to get an access token
      #
      # @return [Faraday::Response]
      def token
        connection.post("/#{base_path}/token") do |req|
          req.headers = default_headers.merge('x-lorota-claims' => claims_token)
          req.body = auth_params.to_json
        end
      end

      # GET request to the data endpoint to get the data stored in LoROTA associated with the uuid
      #
      # @param token [String] LoROTA token
      # @return [Faraday::Response]
      def data(token:)
        connection.get("/#{base_path}/data/#{check_in.uuid}") do |req|
          req.headers = default_headers.merge('Authorization' => "Bearer #{token}")
        end
      end

      private

      def connection
        Faraday.new(url:) do |conn|
          conn.use(:breakers, service_name:)
          conn.response :raise_custom_error, error_prefix: 'LOROTA-API'
          conn.response :betamocks if mock_enabled?

          conn.adapter Faraday.default_adapter
        end
      end

      def default_headers
        {
          'Content-Type' => 'application/json',
          'x-api-key' => api_key,
          'x-apigw-api-id' => api_id
        }
      end

      def auth_params
        {
          lastName: check_in.last_name,
          dob: check_in.dob
        }
      end

      def mock_enabled?
        settings.mock || Flipper.enabled?('check_in_experience_mock_enabled') || false
      end
    end
  end
end
