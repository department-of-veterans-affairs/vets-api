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
end
