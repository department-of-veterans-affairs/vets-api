# frozen_string_literal: true

module AskVAApi
  class RedisClient
    def fetch(key)
      Rails.cache.read(
        key,
        namespace: 'crm-api-cache'
      )
    end

    def store_data(key:, data:, ttl:)
      Rails.cache.write(
        key,
        data,
        namespace: 'crm-api-cache',
        expires_in: ttl
      )
    end
  end
end
