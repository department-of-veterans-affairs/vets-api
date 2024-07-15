# frozen_string_literal: true

module SidekiqConnectivityTest
  def self.test_connectivity
    Sidekiq.redis { |conn| conn.ping == 'PONG' }
  rescue Redis::CannotConnectError => e
    Rails.logger.error "Sidekiq Redis connection failed: #{e.message}"
    false
  end
end

Sidekiq.singleton_class.include(SidekiqConnectivityTest)
