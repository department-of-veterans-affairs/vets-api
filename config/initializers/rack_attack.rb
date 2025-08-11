# frozen_string_literal: true

class Rack::Attack
  # we're behind a load balancer and/or proxy, which is what request.ip returns
  class Request < ::Rack::Request
    def remote_ip
      @remote_ip ||= (env['X-Real-Ip'] || ip).to_s
    end
  end

  Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new($redis)

  throttle('example/ip', limit: 1, period: 5.minutes) do |req|
    req.ip if req.path == '/v0/limited'
  end

  # Rate-limit facilities_va/v2/va lookup -- part of locator.
  # See https://dsva.slack.com/archives/C0FQSS30V/p1695046907329529
  # No systemic failure, but potential "DoS" caused a spike in traffic from one IP.
  throttle('facilities_api/v2/va/ip', limit: 30, period: 1.minute) do |req|
    req.remote_ip if req.path == '/facilities_api/v2/va'
  end

  # Rate-limit PPMS lookup, in order to bore abusers.
  # See https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/Postmortems/2021-08-16-facility-locator-possible-DOS.md
  # for details.
  throttle('facilities_api/v2/ccp/ip', limit: 8, period: 1.minute) do |req|
    req.remote_ip if req.path == '/facilities_api/v2/ccp/provider'
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

  throttle('check_in/ip', limit: 10, period: 1.minute) do |req|
    req.remote_ip if req.path.starts_with?('/check_in') && !Settings.vsp_environment.match?(/local|development|staging/)
  end

  throttle('medical_copays/ip', limit: 20, period: 1.minute) do |req|
    req.remote_ip if req.path.starts_with?('/v0/medical_copays') && req.get?
  end

  # Always allow requests from below IP addresses for load testing
  # `100.103.248.0 - 100.103.248.255`
  # `100.103.251.128 - 100.103.251.255`
  # `10.247.104.` - tevi-dev-load-testing host IPs
  # (blocklist & throttles are skipped)
  Rack::Attack.safelist('allow requests from loadtest host') do |req|
    # Requests are allowed if the return value is truthy
    req.ip.match?(/100.103.248.(\b[0-9]\b|\b[1-9][0-9]\b|1[0-9]{2}|2[0-4][0-9]|25[0-5])
                  |100.103.251.(12[8-9]|1[3-9]\d|2[0-4]\d|25[0-5])
                  |10.247./)
  end

  # Source: https://github.com/kickstarter/rack-attack#x-ratelimit-headers-for-well-behaved-clients
  Rack::Attack.throttled_responder = lambda do |request|
    rate_limit = request.env['rack.attack.match_data']

    now = Time.zone.now
    headers = {
      'X-RateLimit-Limit' => rate_limit[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + (rate_limit[:period] - (now.to_i % rate_limit[:period]))).to_i
    }

    [429, headers, ['throttled']]
  end
end
