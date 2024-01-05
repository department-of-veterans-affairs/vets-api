# frozen_string_literal: true

module Crm
  class StaticData
    ENDPOINT = 'topics'
    CACHE_KEY = 'categories_topics_subtopics'

    attr_reader :cache_client, :service

    def initialize(service: Crm::Service.new(icn: nil), cache_client: RedisClient.new)
      @cache_client = cache_client
      @service = service
    end

    def call
      categories_topics_subtopics = cache_client.fetch(CACHE_KEY)

      return categories_topics_subtopics if categories_topics_subtopics.present?

      static_data = fetch_data

      cache_client.store_data(key: CACHE_KEY, data: static_data, ttl: 86_400)

      static_data
    rescue => e
      ErrorHandler.handle(ENDPOINT, e)
    end

    private

    def fetch_data
      service.call(endpoint: ENDPOINT)
    end
  end
end
