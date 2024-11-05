# frozen_string_literal: true

module RedisHealthChecker
  def self.redis_up
    app_data_redis_up && rails_cache_up && sidekiq_redis_up
  end

  def self.app_data_redis_up
    Thread.current[:app_data_redis_up] ||= begin
      # Test 1: Check attribute that uses redis key
      session = Session.find_or_build('fake token')
      session.update(uuid: '1234')
      Session.delete('fake token')
      session.present?
    rescue => e
      Rails.logger.error(
        { message: "ARGO CD UPGRADE - REDIS TEST: Failed to access app data Redis. Error: #{e.message}" }
      )
      false
    end
  end

  def self.rails_cache_up
    Thread.current[:rails_cache_up] ||= begin
      # Test 2: Check Rails cache Redis
      Rails.cache.write('test_key', 'test_value')
      result = Rails.cache.read('test_key')
      Rails.cache.delete('test_key')
      result == 'test_value'
    rescue => e
      Rails.logger.error(
        { message: "ARGO CD UPGRADE - REDIS TEST: Failed to access Rails cache Redis. Error: #{e.message}" }
      )
      false
    end
  end

  def self.sidekiq_redis_up
    Thread.current[:sidekiq_redis_up] ||= begin
      # Test 3: Check Sidekiq Redis
      Sidekiq.redis do |conn|
        conn.set('test_key', 'test_value')
        result = conn.get('test_key')
        conn.del('test_key')
        result == 'test_value'
      end
    rescue => e
      Rails.logger.error(
        { message: "ARGO CD UPGRADE - REDIS TEST: Failed to access Sidekiq Redis. Error: #{e.message}" }
      )
      false
    end
  end
end
