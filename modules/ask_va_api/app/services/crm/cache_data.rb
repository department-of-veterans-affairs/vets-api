# frozen_string_literal: true

module Crm
  class CacheDataError < StandardError; end
  class ApiServiceError < StandardError; end
  class CacheStoreError < StandardError; end

  class CacheData
    attr_reader :cache_client, :service, :cache_ttl

    DEFAULT_TTL = 86_400

    def initialize(service: Service.new(icn: nil), cache_client: AskVAApi::RedisClient.new, cache_ttl: DEFAULT_TTL)
      @cache_client = cache_client
      @service = service
      @cache_ttl = cache_ttl
    end

    def call(endpoint:, cache_key:, payload: {})
      fetch_cache_data(cache_key) || fetch_and_cache_data(endpoint:, cache_key:, payload:)
    rescue => e
      raise CacheDataError, "#{e.class.name}: #{e.message}"
    end

    def fetch_and_cache_data(endpoint:, cache_key:, payload:)
      data = fetch_api_data(endpoint:, payload:)
      store_in_cache(cache_key, data) if data
      data
    end

    private

    def fetch_cache_data(cache_key)
      cache_client.fetch(cache_key)
    rescue => e
      raise CacheStoreError, "Cache store failure: #{e.message}"
    end

    def fetch_api_data(endpoint:, payload:)
      response = service.call(endpoint:, payload:)
      handle_response_data(response)
    end

    def store_in_cache(cache_key, data)
      cache_client.store_data(key: cache_key, data:, ttl: cache_ttl)
    rescue => e
      raise CacheStoreError, "Failed to store data in cache: #{e.message}"
    end

    def handle_response_data(response)
      return response if response.is_a?(Hash)

      raise ApiServiceError, "Invalid response format: #{response.body}"
    end
  end
end
