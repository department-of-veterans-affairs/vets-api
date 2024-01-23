# frozen_string_literal: true

module Map
  class RedisClient
    def self.build
      new
    end

    def token(patient_icn:)
      Rails.cache.read(
        patient_icn,
        namespace: 'check-in-map-token-cache'
      )
    end

    def save_token(patient_icn:, token:, expires_in:)
      Rails.cache.write(
        patient_icn,
        token,
        namespace: 'check-in-map-token-cache',
        expires_in:
      )
    end
  end
end
