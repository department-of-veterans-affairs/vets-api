# frozen_string_literal: true

module Lighthouse::VeteransHealth
  class JwtWrapper
    def payload
      {
        iss: Settings.lighthouse.veterans_health.fast_tracker.client_id,
        sub: Settings.lighthouse.veterans_health.fast_tracker.client_id,
        aud: Settings.lighthouse.veterans_health.fast_tracker.aud_claim_url,
        exp: 15.minutes.from_now.to_i
      }
    end

    def token
      @token ||= JWT.encode(payload, Configuration.instance.rsa_key, 'RS256')
    end
  end
end
