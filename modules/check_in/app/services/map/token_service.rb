# frozen_string_literal: true

require 'map/security_token/service'

module Map
  ##
  # A class to provide functionality to get token from MAP Secure Token Service
  #
  class TokenService
    attr_reader :patient_icn, :redis_client

    ##
    # Builds a Service instance
    #
    # @param opts [Hash] options to create the object
    #
    # @return [Service] an instance of this class
    #
    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts = {})
      @patient_icn = opts[:patient_icn]
      @redis_client = RedisClient.build
    end

    # Get the auth token. If the token does not already exist in Redis, a call is made to Map token
    # endpoint to retrieve it.
    #
    # @return [String] token
    def token
      @token ||= fetch_or_generate_token
    end

    def fetch_or_generate_token
      token = redis_client.token(patient_icn:)

      return token if token.present?

      current_time = Time.zone.now
      token_response = MAP::SecurityToken::Service.new.token(application: :check_in, icn: patient_icn)

      redis_client.save_token(
        patient_icn:,
        token: token_response[:access_token],
        expires_in: token_response[:expiration] - current_time
      )

      token_response[:access_token]
    end
  end
end
