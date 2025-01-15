# frozen_string_literal: true

module TravelClaim
  ##
  # A class to provide functionality related to BTSSS service. This class needs to be instantiated
  # with a {CheckIn::V2::Session} object so that {Client} can be instantiated appropriately.
  #
  # @!attribute [r] check_in
  #   @return [CheckIn::V2::Session]
  # @!attribute [r] client
  #   @return [Client]
  # @!attribute [r] redis_client
  #   @return [RedisClient]
  class Service
    attr_reader :check_in, :appointment_date, :redis_client, :response, :facility_type, :settings

    ##
    # Builds a Service instance
    #
    # @param opts [Hash] options to create the object
    # @option opts [CheckIn::V2::Session] :check_in the session object
    #
    # @return [Service] an instance of this class
    #
    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts = {})
      @settings = Settings.check_in.travel_reimbursement_api_v2
      @check_in = opts[:check_in]
      @appointment_date = opts.dig(:params, :appointment_date)
      @facility_type = opts.dig(:params, :facility_type) || ''
      @redis_client = RedisClient.build
      @response = Response
    end

    # Get the auth token. If the token does not already exist in Redis, a call is made to VEIS token
    # endpoint to retrieve it.
    #
    # @see TravelClaim::Client#token
    #
    # @return [String] token
    def token
      @token ||= redis_client.token.presence || access_token_from_veis
    end

    # Submit claim for the given patient_icn and appointment time.
    #
    # @see TravelClaim::Client#submit_claim
    #
    # @return [Hash] response hash
    def submit_claim
      resp = if token.present?
               client.submit_claim(token:, patient_icn:, appointment_date:)
             else
               Faraday::Response.new(response_body: { message: 'Unauthorized' }, status: 401)
             end
      response.build(response: resp).handle
    end

    # Check claim status for the given patient_icn and start and end date range.
    #
    # @see TravelClaim::Client#claim_status
    #
    # @return [Hash] response hash
    def claim_status
      start_range_date = end_range_date = appointment_date

      resp = if token.present?
               client.claim_status(token:, patient_icn:, start_range_date:, end_range_date:)
             else
               Faraday::Response.new(response_body: { message: 'Unauthorized' }, status: 401)
             end
      response.build(response: resp).handle_claim_status_response
    end

    private

    def access_token_from_veis
      Oj.safe_load(client.token.body)
        &.fetch('access_token')
        &.tap { |token| redis_client.save_token token: }
    end

    def client
      client_number = facility_type.downcase == 'oh' ? settings.client_number_oh : settings.client_number
      @client ||= Client.build(check_in:, client_number:)
    end

    def patient_icn
      redis_client.icn(uuid: check_in.uuid)
    end
  end
end
