class Rack::Attack
  throttle('feedback/ip', limit: 5, period: 1.hour) do |req|
    if req.path == '/v0/feedback' && req.post?
      req.ip
    end
  end
end
