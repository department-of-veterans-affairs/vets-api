# frozen_string_literal: true

module TravelClaim
  ##
  # A service client for handling HTTP requests to the Travel Reimbursement API.
  #
  class Client
    extend Forwardable
    include SentryLogging

    GRANT_TYPE = 'client_credentials'
    CLAIMANT_ID_TYPE = 'icn'
    TRIP_TYPE = 'RoundTrip'

    attr_reader :settings, :check_in, :client_number

    def_delegators :settings, :auth_url, :tenant_id, :client_id, :client_secret, :scope, :claims_url, :claims_base_path,
                   :subscription_key, :e_subscription_key, :s_subscription_key, :service_name

    ##
    # Builds a Client instance
    #
    # @param opts [Hash] options to create a Client
    # @option opts [CheckIn::V2::Session] :check_in the check_in session object
    # @option opts [String] :client_number the client number to use for the claim
    #
    # @return [TravelClaim::Client] an instance of this class
    #
    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts)
      @settings = Settings.check_in.travel_reimbursement_api_v2
      @check_in = opts[:check_in]
      @client_number = opts[:client_number] || settings.client_number
    end

    ##
    # HTTP POST call to the VEIS Auth endpoint to get the access token
    #
    # @return [Faraday::Response]
    #
    def token
      connection(server_url: auth_url).post("/#{tenant_id}/oauth2/v2.0/token") do |req|
        req.headers = default_headers
        req.body = URI.encode_www_form(auth_params)
      end
    rescue => e
      log_message_to_sentry(e.original_body, :error,
                            { uuid: check_in.uuid },
                            { external_service: service_name, team: 'check-in' })
      raise e
    end

    ##
    # HTTP POST call to the BTSSS ClaimIngest endpoint to submit the claim
    #
    # @return [Faraday::Response]
    #
    def submit_claim(token:, patient_icn:, appointment_date:)
      connection(server_url: claims_url).post("/#{claims_base_path}/api/ClaimIngest/submitclaim") do |req|
        req.options.timeout = 120
        req.headers = claims_default_header.merge('Authorization' => "Bearer #{token}")
        req.body = submit_claim_data.merge({
                                             ClaimantID: patient_icn,
                                             Appointment: {
                                               AppointmentDateTime: appointment_date
                                             }
                                           }).to_json
      end
    rescue Faraday::TimeoutError
      Rails.logger.error(message: 'BTSSS Timeout Error', uuid: check_in.uuid)
      Faraday::Response.new(response_body: { message: 'BTSSS timeout error' }, status: 408)
    rescue => e
      log_message_to_sentry(e.original_body, :error,
                            { uuid: check_in.uuid },
                            { external_service: service_name, team: 'check-in' })
      Faraday::Response.new(response_body: e.original_body, status: e.original_status)
    end

    ##
    # HTTP POST call to the BTSSS Claim Status endpoint to check the status of an existing claim
    #
    # @return [Faraday::Response]
    #
    def claim_status(token:, patient_icn:, start_range_date:, end_range_date:)
      connection(server_url: claims_url).post("/#{claims_base_path}/api/ClaimIngest/V1/GetClaimsStatus") do |req|
        req.options.timeout = 120
        req.headers = claims_default_header.merge('Authorization' => "Bearer #{token}")
        req.body = claim_status_data.merge({
                                             vetId: patient_icn,
                                             startRangeDate: start_range_date,
                                             endRangeDate: end_range_date
                                           }).to_json
      end
    rescue Faraday::TimeoutError
      Rails.logger.error(message: 'BTSSS Timeout Error', uuid: check_in.uuid)
      Faraday::Response.new(response_body: { message: 'BTSSS timeout error' }, status: 408)
    rescue => e
      log_message_to_sentry(e.original_body, :error,
                            { uuid: check_in.uuid },
                            { external_service: service_name, team: 'check-in' })
      Faraday::Response.new(response_body: e.original_body, status: e.original_status)
    end

    def submit_claim_v2(token, opts)
      patient_identifier_type = opts.fetch(:patient_identifier_type, 'icn')

      connection(server_url: claims_url).post("/#{claims_base_path}/api/ClaimIngest/submitclaim") do |req|
        req.options.timeout = 120
        req.headers = claims_default_header.merge('Authorization' => "Bearer #{token}")
        req.body = submit_claim_data.merge({
                                             ClaimantID: opts[:patient_identifier],
                                             ClaimantIDType: patient_identifier_type,
                                             Appointment: { AppointmentDateTime: opts[:appointment_date] }
                                           }).to_json
      end
    rescue Faraday::TimeoutError
      Rails.logger.error(message: 'BTSSS Timeout Error', uuid: check_in.uuid)
      Faraday::Response.new(response_body: { message: 'BTSSS timeout error' }, status: 408)
    rescue => e
      log_message_to_sentry(e.original_body, :error,
                            { uuid: check_in.uuid },
                            { external_service: service_name, team: 'check-in' })
      Faraday::Response.new(response_body: e.original_body, status: e.original_status)
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

    def claims_default_header
      if Settings.vsp_environment == 'production'
        {
          'Content-Type' => 'application/json',
          'OCP-APIM-Subscription-Key-E' => e_subscription_key,
          'OCP-APIM-Subscription-Key-S' => s_subscription_key
        }
      else
        {
          'Content-Type' => 'application/json',
          'OCP-APIM-Subscription-Key' => subscription_key
        }
      end
    end

    def auth_params
      {
        client_id:,
        client_secret:,
        scope:,
        grant_type: GRANT_TYPE
      }
    end

    def submit_claim_data
      {
        ClientNumber: client_number,
        ClaimantIDType: CLAIMANT_ID_TYPE,
        MileageExpense: {
          TripType: TRIP_TYPE
        }
      }
    end

    def claim_status_data
      {
        clientNumber: client_number,
        vetIdType: CLAIMANT_ID_TYPE
      }
    end

    def auth_url
      settings.auth_url_v2
    end

    def claims_url
      settings.claims_url_v2
    end

    def mock_enabled?
      settings.mock || Flipper.enabled?('check_in_experience_mock_enabled') || false
    end
  end
end
