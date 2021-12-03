# frozen_string_literal: true

module V2
  module Chip
    ##
    # A service client for handling HTTP requests to the CHIP API.
    #
    # @!attribute settings
    #   @return [Config::Options]
    # @!attribute claims_token
    #   @return [V2::Chip::ClaimsToken]
    # @!attribute check_in_session
    #   @return [CheckIn::V2::Session]
    # @!method base_path
    #   @return (see Config::Options#base_path)
    # @!method tmp_api_id
    #   @return (see Config::Options#tmp_api_id)
    # @!method url
    #   @return (see Config::Options#url)
    # @!method service_name
    #   @return (see Config::Options#service_name)
    class Client
      extend Forwardable

      attr_reader :settings, :claims_token, :check_in_session

      def_delegators :settings, :base_path, :tmp_api_id, :url, :service_name

      ##
      # Builds a Client instance
      #
      # @param opts [Hash]
      # @return [V2::Chip::Client] an instance of this class
      #
      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @settings = Settings.check_in.chip_api_v2
        @claims_token = ClaimsToken.build
        @check_in_session = opts[:check_in_session]
      end

      ##
      # HTTP POST call to the CHIP API to get an access token
      #
      # @return [Faraday::Response]
      #
      def token
        connection.post("/#{base_path}/token") do |req|
          req.headers = default_headers.merge('Authorization' => "Basic #{claims_token.static}")
        end
      end

      ##
      # HTTP POST call to the CHIP API to Check-in an appointment
      #
      # @return [Faraday::Response]
      #
      def check_in_appointment(token:, appointment_ien:)
        connection.post("/#{base_path}/actions/check-in/#{check_in_session.uuid}") do |req|
          req.headers = default_headers.merge('Authorization' => "Bearer #{token}")
          req.body = { appointmentIEN: appointment_ien }.to_json
        end
      end

      ##
      # HTTP POST call to the CHIP API to refresh appointments
      #
      # @return [Faraday::Response]
      #
      def refresh_appointments(token:, identifier_params:)
        connection.post("/#{base_path}/actions/refresh-appointments/#{check_in_session.uuid}") do |req|
          req.headers = default_headers.merge('Authorization' => "Bearer #{token}")
          req.body = identifier_params.to_json
        end
      end

      ##
      # HTTP POST call to the CHIP API to confirm pre check-in
      #
      # @return [Faraday::Response]
      #
      def pre_check_in(token:, demographic_confirmations:)
        connection.post("/#{base_path}/actions/pre-checkin/#{check_in_session.uuid}") do |req|
          req.headers = default_headers.merge('Authorization' => "Bearer #{token}")
          req.body = demographic_confirmations.to_json
        end
      end

      private

      ##
      # Create a Faraday connection object that glues the attributes
      # and the middleware stack for making our HTTP requests to Chip
      #
      # @return [Faraday::Connection]
      #
      def connection
        Faraday.new(url: url) do |conn|
          conn.use :breakers
          conn.response :raise_error, error_prefix: service_name
          conn.adapter Faraday.default_adapter
        end
      end

      ##
      # Build a hash of default headers for CHIP HTTP requests
      #
      # @return [Hash]
      #
      def default_headers
        {
          'Content-Type' => 'application/json',
          'x-apigw-api-id' => tmp_api_id
        }
      end
    end
  end
end
