# frozen_string_literal: true

class Rack::Attack
  REDIS_CONFIG = Rails.application.config_for(:redis).freeze
  Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new(Redis.new(REDIS_CONFIG['redis']))

  throttle('feedback/ip', limit: 5, period: 1.hour) do |req|
    req.ip if req.path == '/v0/feedback' && req.post?
  end

  throttle('example/ip', limit: 1, period: 5.minutes) do |req|
    req.ip if req.path == '/v0/limited'
  end

  throttle('vic_profile_photos/ip', limit: 4, period: 5.minutes) do |req|
    req.ip if req.path == '/v0/vic/profile_photo_attachments'
  end

  throttle('vic_supporting_docs/ip', limit: 4, period: 5.minutes) do |req|
    req.ip if req.path == '/v0/vic/supporting_documentation_attachments'
  end

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
