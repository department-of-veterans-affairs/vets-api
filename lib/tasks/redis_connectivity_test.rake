require 'redis'

namespace :redis do
  desc "Test Redis connectivity"
  task test_connectivity: :environment do
    def safe_connection_info(redis_instance)
      return 'Not available' unless redis_instance.respond_to?(:connection)
      begin
        info = redis_instance.connection
        "#{info[:host]}:#{info[:port]}"
      rescue => e
        "Error getting connection info: #{e.message}"
      end
    end

    def test_connection(name, redis_instance)
      return [false, "#{name}: Skipped (Redis not configured)"] unless redis_instance

      start_time = Time.now
      response = redis_instance.ping
      end_time = Time.now

      if response == 'PONG'
        [true, "#{name}: Connected\n  URL: #{safe_connection_info(redis_instance)}\n  Response time: #{(end_time - start_time) * 1000} ms"]
      else
        [false, "#{name}: Failed (unexpected response)"]
      end
    rescue Redis::CannotConnectError => e
      [false, "#{name}: Failed (connection error)\n  Error: #{e.message}"]
    rescue => e
      [false, "#{name}: Failed (unexpected error)\n  Error: #{e.message}\n  Backtrace:\n#{e.backtrace.join("\n")}"]
    end

    results = {
      redis_store: test_connection('Redis Store', Redis.new(url: Settings.redis.app_data.url)),
      rails_cache: test_connection('Rails Cache', Rails.cache.is_a?(ActiveSupport::Cache::RedisCacheStore) ? Rails.cache.redis : nil),
      sidekiq: Sidekiq.redis { |conn| test_connection('Sidekiq', conn) }
    }

    puts "\nResults:"
    results.each do |service, (success, message)|
      puts message
    end

    exit 1 unless results.values.all? { |success, _| success }
  end
end