# frozen_string_literal: true

module V2
  module Chip
    class RedisHandler
      attr_reader :session_id
      attr_accessor :token

      def self.build(session_id: nil)
        new(session_id)
      end

      def initialize(session_id)
        @session_id = session_id
      end

      def get
        Rails.cache.read(
          session_id,
          namespace: 'check-in-chip-v2-cache'
        )
      end

      def save
        Rails.cache.write(
          session_id,
          token.access_token,
          namespace: 'check-in-chip-v2-cache',
          expires_in: 14.minutes
        )
      end
    end
  end
end
