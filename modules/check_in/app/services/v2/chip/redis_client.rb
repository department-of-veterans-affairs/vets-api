# frozen_string_literal: true

module V2
  module Chip
    class RedisClient
      extend Forwardable

      attr_reader :settings

      def_delegators :settings, :redis_session_prefix

      def self.build
        new
      end

      def initialize
        @settings = Settings.check_in.chip_api_v2
      end

      def get
        Rails.cache.read(
          session_id,
          namespace: 'check-in-chip-v2-cache'
        )
      end

      def save(token:)
        Rails.cache.write(
          session_id,
          token,
          namespace: 'check-in-chip-v2-cache',
          expires_in: 14.minutes
        )
      end

      def session_id
        @session_id ||= "#{redis_session_prefix}_#{tmp_api_id}"
      end

      def use_vaec_cie_endpoints?
        Flipper.enabled?('check_in_experience_use_vaec_cie_endpoints') || false
      end

      def tmp_api_id
        use_vaec_cie_endpoints? ? settings.tmp_api_id_v2 : settings.tmp_api_id
      end
    end
  end
end
