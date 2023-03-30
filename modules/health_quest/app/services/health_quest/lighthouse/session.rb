# frozen_string_literal: true

module HealthQuest
  module Lighthouse
    ##
    # An object responsible for establishing a session between the vets-api and
    # the Lighthouse so that PGD resources can be fetched and created.
    #
    # @!attribute api
    #   @return [String]
    # @!attribute user
    #   @return [User]
    # @!attribute id
    #   @return [String]
    # @!attribute redis_handler
    #   @return [Lighthouse::RedisHandler]
    # @!attribute token
    #   @return [Lighthouse::Token]
    #
    class Session
      attr_reader :api, :user, :id, :redis_handler, :token

      ##
      # Builds a Lighthouse::Session instance from a given User
      #
      # @param user [User] the currently logged in user
      # @param api [String] the Lighthouse api
      # @return [Lighthouse::Session] an instance of this class
      #
      def self.build(user:, api:)
        new(user:, api:)
      end

      def initialize(opts)
        @api = opts[:api]
        @user = opts[:user]
        @token = Token.build(user:, api:)
        @id = session_id
        @redis_handler = RedisHandler.build(session_id: id)
      end

      ##
      # Gets the active session from redis for the logged in user
      # or creates a new one in redis by first obtaining
      # an access_token from Lighthouse
      #
      # @return [HealthQuest::SessionStore]
      #
      def retrieve
        session = session_from_redis
        return session if session.present?

        establish_lighthouse_session
      end

      ##
      # Gets the active session from redis for the logged in user
      #
      # @return [HealthQuest::SessionStore]
      #
      def session_from_redis
        redis_handler.get
      end

      ##
      # Makes the call to `lighthouse_access_token` and saves the token
      # to a SessionStore in Redis
      #
      # @return [HealthQuest::SessionStore]
      #
      def establish_lighthouse_session
        redis_handler.token = lighthouse_access_token
        redis_handler.save
      end

      ##
      # Fetches a new access_token from Lighthouse for the logged in user
      #
      # @return [HealthQuest::SessionStore]
      #
      def lighthouse_access_token
        token.fetch
      end

      ##
      # Builds the session_id based on which Lighthouse api the request is being made to
      #
      # @return [String]
      #
      def session_id
        @build_session_id ||= "#{lighthouse_prefix}_#{api}_#{account_uuid}"
      end

      private

      def lighthouse_prefix
        Settings.hqva_mobile.lighthouse.redis_session_prefix
      end

      def account_uuid
        user&.account_uuid
      end
    end
  end
end
