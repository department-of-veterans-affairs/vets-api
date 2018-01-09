# frozen_string_literal: true
class Rack::Attack
  throttle('feedback/ip', limit: 5, period: 1.hour) do |req|
    req.ip if req.path == '/v0/feedback' && req.post?
  end

  throttle('example/ip', limit: 1, period: 5.minutes) do |req|
    req.ip if req.path == '/v0/limited'
  end
end
