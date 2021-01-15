# frozen_string_literal: true

module HealthQuest
  module Lighthouse
    ##
    # An object responsible for facilitating communication between Lighthouse::Session and redis
    #
    # @!attribute session_id
    #   @return [String]
    # @!attribute session_store
    #   @return [Lighthouse::SessionStore]
    # @!attribute token
    #   @return [Lighthouse::Token]
    class RedisHandler
      attr_reader :session_id, :session_store
      attr_accessor :token

      ##
      # Builds a Lighthouse::RedisHandler instance from a session_id and session_store
      #
      # @param session_id [String] the users unique id for creating a token in redis.
      # @param session_store [SessionStore] an object for calling redis functions.
      #
      # @return [Lighthouse::RedisHandler] an instance of this class
      #
      def self.build(session_id: nil, session_store: SessionStore)
        new(session_id, session_store)
      end

      def initialize(session_id, session_store)
        @session_id = session_id
        @session_store = session_store
      end

      ##
      # Gets the active session from redis for by the given lighthouse session_id
      #
      # @return [HealthQuest::SessionStore]
      #
      def get
        session_store.find(session_id)
      end

      ##
      # Saves the session in redis from the newly obtained lighthouse access_token
      #
      # @return [HealthQuest::SessionStore]
      #
      def save
        hash = {
          account_uuid: session_id,
          token: token&.access_token,
          unix_created_at: token&.created_at
        }

        session_store.new(hash).tap do |ss|
          ss.save
          ss.expire(token&.ttl_duration)
        end
      end
    end
  end
end
