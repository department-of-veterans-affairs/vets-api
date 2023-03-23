# frozen_string_literal: true

module V2
  module Lorota
    class RedisClient
      extend Forwardable

      attr_reader :lorota_v2_settings, :authentication_settings

      def_delegators :@lorota_v2_settings, :redis_session_prefix, :redis_token_expiry
      def_delegator :@authentication_settings, :retry_attempt_expiry

      def self.build
        new
      end

      def initialize
        @lorota_v2_settings = Settings.check_in.lorota_v2
        @authentication_settings = Settings.check_in.authentication
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
          expires_in: redis_token_expiry
        )
      end

      def retry_attempt_count(uuid:)
        Rails.cache.read(
          retry_attempt_prefix(uuid:),
          namespace: 'check-in-lorota-v2-cache'
        )
      end

      def save_retry_attempt_count(uuid:, retry_count:)
        Rails.cache.write(
          retry_attempt_prefix(uuid:),
          retry_count,
          namespace: 'check-in-lorota-v2-cache',
          expires_in: retry_attempt_expiry
        )
      end

      def session_id_prefix(uuid:)
        "#{redis_session_prefix}_#{uuid}_read.full"
      end

      def retry_attempt_prefix(uuid:)
        "authentication_retry_limit_#{uuid}"
      end
    end
  end
end
