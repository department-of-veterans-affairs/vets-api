# frozen_string_literal: true

module V2
  module Lorota
    class RedisClient
      extend Forwardable

      attr_reader :settings

      def_delegators :settings, :redis_session_prefix

      def self.build
        new
      end

      def initialize
        @settings = Settings.check_in.lorota_v2
      end

      def get(check_in_uuid:)
        Rails.cache.read(
          session_id_prefix(uuid: check_in_uuid),
          namespace: 'check-in-lorota-v2-cache'
        )
      end

      def save(check_in_uuid:, token:)
        Rails.cache.write(
          session_id_prefix(uuid: check_in_uuid),
          token,
          namespace: 'check-in-lorota-v2-cache',
          expires_in: 1440.minutes
        )
      end

      def session_id_prefix(uuid:)
        "#{redis_session_prefix}_#{uuid}_read.full"
      end
    end
  end
end
