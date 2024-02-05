# frozen_string_literal: true

module Crm
  class CacheData
    attr_reader :cache_client, :service

    def initialize(service: Service.new(icn: nil), cache_client: RedisClient.new)
      @cache_client = cache_client
      @service = service
    end

    def call(endpoint, cache_key)
      data = cache_client.fetch(cache_key)

      if data.nil?
        fetch_api_data(endpoint, cache_key)
      else
        data
      end
    rescue => e
      ErrorHandler.handle(endpoint, e)
    end

    def fetch_api_data(endpoint, cache_key)
      data = service.call(endpoint:)

      cache_client.store_data(key: cache_key, data:, ttl: 86_400)

      data
    rescue => e
      ErrorHandler.handle(endpoint, e)
    end
  end
end
