# frozen_string_literal: true

module CacheConnectivityTest
  def self.test_connectivity
    Rails.cache.redis.ping == 'PONG'
  rescue Redis::CannotConnectError => e
    Rails.logger.error "Rails cache connection failed: #{e.message}"
    false
  end
end

Rails.cache.singleton_class.include(CacheConnectivityTest)
