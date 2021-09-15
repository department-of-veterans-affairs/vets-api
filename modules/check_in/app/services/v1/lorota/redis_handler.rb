# frozen_string_literal: true

module V1
  module Lorota
    class RedisHandler < BasicRedisHandler
      def build_session_id_prefix
        @build_session_id_prefix ||= "#{redis_session_prefix}_#{check_in.uuid}_read.full"
      end
    end
  end
end
