# frozen_string_literal: true

module V1
  module Lorota
    class BasicRedisHandler
      extend Forwardable

      attr_reader :check_in, :settings
      attr_accessor :token

      def_delegators :settings, :redis_session_prefix, :redis_token_expiry

      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @settings = Settings.check_in.lorota_v1
        @check_in = opts[:check_in]
      end

      def get
        Rails.cache.read(
          build_session_id_prefix,
          namespace: 'check-in-lorota-v1-cache'
        )
      end

      def save
        Rails.cache.write(
          build_session_id_prefix,
          token.access_token,
          namespace: 'check-in-lorota-v1-cache',
          expires_in: redis_token_expiry
        )
      end

      def build_session_id_prefix
        @build_session_id_prefix ||= "#{redis_session_prefix}_#{check_in.uuid}_read.basic"
      end
    end
  end
end
