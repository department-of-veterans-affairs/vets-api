# frozen_string_literal: true

module Crm
  class CacheData
    attr_reader :cache_client, :service

    def initialize(service: Service.new(icn: nil), cache_client: AskVAApi::RedisClient.new)
      @cache_client = cache_client
      @service = service
    end

    def call(endpoint:, cache_key:, payload: {})
      data = cache_client.fetch(cache_key)

      data = fetch_api_data(endpoint:, cache_key:, payload:) if data.nil?

      data
    rescue => e
      ::ErrorHandler.handle_service_error(e)
    end

    def fetch_api_data(endpoint:, cache_key:, payload: {})
      response = service.call(endpoint:, payload:)
      data = handle_response_data(response)

      cache_client.store_data(key: cache_key, data:, ttl: 86_400)

      data
    end

    private

    def handle_response_data(response)
      case response
      when Hash
        response
      else
        raise(StandardError, response.body)
      end
    end
  end
end
