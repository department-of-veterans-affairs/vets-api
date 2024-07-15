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
      start_time = Time.now
      response = redis_instance.ping
      end_time = Time.now

      if response == 'PONG'
        puts "#{name}: Connected"
        puts "  URL: #{safe_connection_info(redis_instance)}"
        puts "  Response time: #{(end_time - start_time) * 1000} ms"
        true
      else
        puts "#{name}: Failed (unexpected response)"
        false
      end
    rescue Redis::CannotConnectError => e
      puts "#{name}: Failed (connection error)"
      puts "  Error: #{e.message}"
      false
    rescue => e
      puts "#{name}: Failed (unexpected error)"
      puts "  Error: #{e.message}"
      puts "  Backtrace:"
      puts e.backtrace.join("\n")
      false
    end

    results = {
      redis_store: test_connection('Redis Store', Redis.new(url: Settings.redis.app_data.url)),
      rails_cache: test_connection('Rails Cache', Rails.cache.redis),
      sidekiq: Sidekiq.redis { |conn| test_connection('Sidekiq', conn) }
    }

    puts "\nOverall Results:"
    results.each do |service, result|
      puts "#{service}: #{result ? 'Connected' : 'Failed'}"
    end

    exit 1 unless results.values.all?
  end
end