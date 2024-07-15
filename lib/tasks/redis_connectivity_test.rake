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

    def test_connection(name, redis_url)
      puts "Testing #{name} with URL: #{redis_url}"
      redis_instance = Redis.new(url: redis_url)
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

    redis_url = ENV['REDIS_URL'] || Settings.redis.app_data.url
    puts "Using REDIS_URL: #{redis_url}"

    results = {
      redis_store: test_connection('Redis Store', redis_url),
      rails_cache: test_connection('Rails Cache', redis_url),
      sidekiq: test_connection('Sidekiq', redis_url)
    }

    puts "\nResults:"
    results.each do |service, (success, message)|
      puts message
    end

    exit 1 unless results.values.all? { |success, _| success }
  end
end