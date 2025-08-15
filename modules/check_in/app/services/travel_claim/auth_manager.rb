# frozen_string_literal: true

module TravelClaim
  class AuthManager < BaseClient
    attr_reader :redis_client, :check_in_session

    CACHE_NAMESPACE = 'check-in-travel-pay-cache'
    CACHE_KEY_PREFIX = 'travel_pay_v4_token'

    def initialize(check_in_session: nil)
      super()
      @check_in_session = check_in_session
      @redis_client = ::TravelClaim::RedisClient.build
      @token_client = TokenClient.new
    end

    # Returns a BTSSS system access token (v4)
    # If icn is nil, attempts to resolve from Redis using check_in_session
    # Caches token per ICN (non-PHI keys)
    def authorize(icn: nil)
      resolved_icn = resolve_icn(icn)
      raise ArgumentError, 'ICN not available' if resolved_icn.blank?

      key = secure_cache_key(resolved_icn)
      cached = redis_client.v4_token(cache_key: key)
      return cached if cached.present?

      veis_access_token = veis_access_token!
      v4_resp = @token_client.system_access_token_v4(veis_access_token:, icn: resolved_icn)
      access_token = Oj.safe_load(v4_resp.body).dig('data', 'accessToken')

      redis_client.save_v4_token(cache_key: key, token: access_token)
      access_token
    end

    # Mirrors travel_pay behavior: requests fresh VEIS and BTSSS(v4) tokens, persists them, and returns both.
    def request_new_tokens(icn: nil)
      resolved_icn = resolve_icn(icn)
      raise ArgumentError, 'ICN not available' if resolved_icn.blank?

      veis_access_token = veis_access_token!
      # Persist VEIS token for legacy consumers using the existing Redis client contract
      redis_client.save_token(token: veis_access_token)

      v4_resp = @token_client.system_access_token_v4(veis_access_token:, icn: resolved_icn)
      access_token = Oj.safe_load(v4_resp.body).dig('data', 'accessToken')

      # Persist v4 system token under a secure, non-PHI cache key
      key = secure_cache_key(resolved_icn)
      redis_client.save_v4_token(cache_key: key, token: access_token)

      { veis_token: veis_access_token, btsss_token: access_token }
    end

    private

    def veis_access_token!
      resp = @token_client.veis_token
      Oj.safe_load(resp.body).fetch('access_token')
    end

    def resolve_icn(passed_icn)
      return passed_icn if passed_icn.present?
      return nil if check_in_session.nil?

      redis_client.icn(uuid: check_in_session.uuid)
    end

    # Build a non-PHI cache key. Prefer session UUID when available; otherwise HMAC the ICN.
    def secure_cache_key(icn)
      if check_in_session&.uuid.present?
        "#{CACHE_KEY_PREFIX}:session:#{check_in_session.uuid}"
      else
        secret = cache_key_secret
        digest = OpenSSL::HMAC.hexdigest('SHA256', secret, icn.to_s)
        "#{CACHE_KEY_PREFIX}:icn_hmac:#{digest}"
      end
    end

    def cache_key_secret
      explicit = settings.respond_to?(:cache_key_secret) ? settings.cache_key_secret : nil
      candidates = [
        explicit.to_s.presence,
        Rails.application.credentials.secret_key_base.to_s,
        'checkin-travel-pay'
      ]
      candidates.find(&:present?)
    end

    def settings
      @settings ||= Settings.check_in.travel_reimbursement_api_v2
    end
  end
end
