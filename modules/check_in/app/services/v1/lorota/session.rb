# frozen_string_literal: true

module V1
  module Lorota
    class Session < BasicSession
      def initialize(opts)
        @check_in = opts[:check_in]
        @token = Token.build(check_in: check_in)
        @redis_handler = RedisHandler.build(check_in: check_in)
      end
    end
  end
end
