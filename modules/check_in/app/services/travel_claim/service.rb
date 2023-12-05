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
    attr_reader :check_in, :appointment_date, :client, :redis_client, :response

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
      @check_in = opts[:check_in]
      @appointment_date = opts.dig(:params, :appointment_date)
      @client = Client.build(check_in:)
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
      @token ||= begin
        token = redis_client.token

        return token if token.present?

        resp = client.token

        Oj.load(resp.body)&.fetch('access_token').tap do |access_token|
          redis_client.save_token(token: access_token)
        end
      end
    end

    # Submit claim for the given patient_icn and appointment time.
    #
    # @see TravelClaim::Client#submit_claim
    #
    # @return [Response] claimNumber
    def submit_claim
      resp = if token.present?
               client.submit_claim(token:, patient_icn:, appointment_date:)
             else
               Faraday::Response.new(body: { message: 'Unauthorized' }, status: 401)
             end
      response.build(response: resp).handle
    end

    private

    def patient_icn
      redis_client.icn(uuid: check_in.uuid)
    end
  end
end
