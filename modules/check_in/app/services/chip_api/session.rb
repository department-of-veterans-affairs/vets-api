# frozen_string_literal: true

module ChipApi
  ##
  # An object responsible for establishing a "session" between
  # the vets-api and the CHIP API so that data can be accessed
  # on behalf of the patient
  #
  # @!attribute redis_handler
  #   @return [ChipApi::RedisHandler]
  # @!attribute token
  #   @return [ChipApi::Token]
  #
  class Session
    attr_reader :redis_handler, :token

    ##
    # Builds a ChipApi::Session instance
    #
    # @return [ChipApi::Session] an instance of this class
    #
    def self.build
      new
    end

    def initialize
      @token = Token.build
      @redis_handler = RedisHandler.build(session_id: session_id)
    end

    ##
    # Gets the active token from redis for the vets_api
    # or creates a new one in redis by first obtaining
    # an access_token from Lighthouse
    #
    # @return [String]
    #
    def retrieve
      session = session_from_redis
      return session if session.present?

      establish_chip_session
    end

    ##
    # Gets the active token from redis
    #
    # @return [String]
    #
    def session_from_redis
      redis_handler.get
    end

    ##
    # Makes the call to the CHIP API token endpoint and
    # saves it in Redis. Returns the token when the method runs
    #
    # @return [String]
    #
    def establish_chip_session
      redis_handler.token = token.fetch
      redis_handler.save
      session_from_redis
    end

    ##
    # Builds the session_id for Redis
    #
    # @return [String]
    #
    def session_id
      @session_id ||= "#{chip_api.redis_session_prefix}_#{token.claims_token.api_id}"
    end

    private

    def chip_api
      Settings.check_in.chip_api
    end
  end
end
