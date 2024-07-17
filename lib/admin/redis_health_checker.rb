# frozen_string_literal: true

module RedisHealthChecker
  def self.redis_up
    app_data_redis_up && rails_cache_up && sidekiq_redis_up
  end

  def self.app_data_redis_up
    # Test 1: Check attribute that uses redis key
    bank_name = BankName.find_or_build('fake routing number')
    bank_name.update(bank_name: 'fake bank name')
    BankName.delete('fake routing number')
    bank_name.present?
  rescue => e
    Rails.logger.error(
      { message: "ARGO CD UPGRADE - REDIS TEST: Failed to access app data Redis. Error: #{e.message}" }
    )
    false
  end

  def self.rails_cache_up
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

  def self.sidekiq_redis_up
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
