# frozen_string_literal: true

module ChipApi
  ##
  # An object responsible for facilitating communication between ChipApi::Session and redis
  #
  # @!attribute session_id
  #   @return [String]
  # @!attribute token
  #   @return [ChipApi::Token]
  class RedisHandler
    attr_reader :session_id
    attr_accessor :token

    ##
    # Builds a ChipApi::RedisHandler instance from a session_id and session_store
    #
    # @param session_id [String] the users unique id for creating a token in redis.
    # @return [ChipApi::RedisHandler] an instance of this class
    #
    def self.build(session_id: nil)
      new(session_id)
    end

    def initialize(session_id)
      @session_id = session_id
    end

    ##
    # Gets the active CHIP API token from redis
    #
    # @return [String]
    #
    def get
      Rails.cache.read(session_id, namespace: 'check-in-cache')
    end

    ##
    # Saves the CHIP API token in redis
    #
    # @return [Boolean]
    #
    def save
      Rails.cache.write(session_id, token.access_token, namespace: 'check-in-cache', expires_in: 14.minutes)
    end
  end
end
