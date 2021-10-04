# frozen_string_literal: true

module V2
  module Chip
    class Session
      extend Forwardable

      attr_reader :redis_handler, :token, :settings

      def_delegators :settings, :redis_session_prefix

      def self.build
        new
      end

      def initialize
        @settings = Settings.check_in.chip_api_v2
        @token = Token.build
        @redis_handler = RedisHandler.build(session_id: session_id)
      end

      def retrieve
        session = session_from_redis
        return session if session.present?

        establish_chip_session
      end

      def session_from_redis
        redis_handler.get
      end

      def establish_chip_session
        redis_handler.token = token.fetch
        redis_handler.save
        session_from_redis
      end

      def session_id
        @session_id ||= "#{redis_session_prefix}_#{token.claims_token.tmp_api_id}"
      end
    end
  end
end
