# frozen_string_literal: true

module V2
  module Lorota
    class Session
      attr_reader :check_in, :token, :redis_handler

      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @check_in = opts[:check_in]
        @token = Token.build(check_in: check_in)
        @redis_handler = RedisHandler.build(check_in: check_in)
      end

      def from_redis
        redis_handler.get
      end

      def from_lorota
        redis_handler.token = token.fetch
        redis_handler.save
        redis_handler.get
      end
    end
  end
end
