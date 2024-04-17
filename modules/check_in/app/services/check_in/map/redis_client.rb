# frozen_string_literal: true

module CheckIn
  module Map
    class RedisClient
      def self.build
        new
      end

      def token(check_in_uuid:)
        Rails.cache.read(
          check_in_uuid,
          namespace: 'check-in-map-token-cache'
        )
      end

      def save_token(check_in_uuid:, token:, expires_in:)
        Rails.cache.write(
          check_in_uuid,
          token,
          namespace: 'check-in-map-token-cache',
          expires_in:
        )
      end
    end
  end
end
