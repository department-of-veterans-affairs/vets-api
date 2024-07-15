module SidekiqConnectivityTest
  def self.test_connectivity
    begin
      Sidekiq.redis { |conn| conn.ping == 'PONG' }
    rescue Redis::CannotConnectError => e
      Rails.logger.error "Sidekiq Redis connection failed: #{e.message}"
      false
    end
  end
end

Sidekiq.singleton_class.include(SidekiqConnectivityTest)