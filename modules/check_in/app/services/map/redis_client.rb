# frozen_string_literal: true

module Map
  class RedisClient
    def self.build
      new
    end

    def token(patient_identifier:)
      Rails.cache.read(
        patient_identifier,
        namespace: 'check-in-map-token-cache'
      )
    end

    def save_token(patient_identifier:, token:, expires_in:)
      Rails.cache.write(
        patient_identifier,
        token,
        namespace: 'check-in-map-token-cache',
        expires_in:
      )
    end
  end
end
