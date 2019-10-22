# frozen_string_literal: true

class Rack::Attack
  REDIS_CONFIG = Rails.application.config_for(:redis).freeze
  Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new(Redis.new(REDIS_CONFIG['redis']))

  throttle('example/ip', limit: 1, period: 5.minutes) do |req|
    req.ip if req.path == '/v0/limited'
  end

  throttle('vic_profile_photos_download/ip', limit: 8, period: 5.minutes) do |req|
    req.ip if req.path == '/v0/vic/profile_photo_attachments' && req.get?
  end

  throttle('vic_profile_photos_upload/ip', limit: 8, period: 5.minutes) do |req|
    req.ip if req.path == '/v0/vic/profile_photo_attachments' && req.post?
  end

  throttle('vic_supporting_docs_upload/ip', limit: 8, period: 5.minutes) do |req|
    req.ip if req.path == '/v0/vic/supporting_documentation_attachments' && req.post?
  end

  throttle('vic_submissions/ip', limit: 10, period: 1.minute) do |req|
    req.ip if req.path == '/v0/vic/vic_submissions' && req.post?
  end

  throttle('evss_claims_async', limit: 12, period: 60) do |req|
    req.ip if req.path == '/v0/evss_claims_async'
  end

  # Source: https://github.com/kickstarter/rack-attack#x-ratelimit-headers-for-well-behaved-clients
  Rack::Attack.throttled_response = lambda do |env|
    rate_limit = env['rack.attack.match_data']

    now = Time.zone.now
    headers = {
      'X-RateLimit-Limit' => rate_limit[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + (rate_limit[:period] - now.to_i % rate_limit[:period])).to_i
    }

    [429, headers, ['throttled']]
  end
end
