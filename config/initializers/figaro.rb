Figaro.require_keys("CERTIFICATE_FILE", "KEY_FILE", "REDIS_HOST", "REDIS_PORT", "DB_ENCRYPTION_KEY")

if Rails.env.production?
  Figaro.require_keys('SIDEKIQ_USERNAME', 'SIDEKIQ_PASSWORD')
end
