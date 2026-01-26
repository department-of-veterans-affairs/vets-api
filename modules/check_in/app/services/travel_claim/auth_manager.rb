# frozen_string_literal: true

module TravelClaim
  ##
  # Manages authentication tokens for Travel Claim API operations.
  #
  # Handles token acquisition, caching, and refresh for VEIS and BTSSS v4 tokens.
  # Uses Redis for caching with non-PHI keys. Expects to be provided by an orchestrator.
  #
  class AuthManager
    attr_reader :redis_client, :check_in_session

    CACHE_NAMESPACE = 'check-in-travel-pay-cache'
    CACHE_KEY_PREFIX = 'travel_pay_v4_token'

    ##
    # Initializes the AuthManager with optional check-in session.
    #
    # @param check_in_session [CheckIn::V2::Session, nil] Optional session for ICN resolution
    #
    def initialize(check_in_session: nil)
      @settings = Settings.check_in.travel_reimbursement_api_v2
      @check_in_session = check_in_session
      @redis_client = ::TravelClaim::RedisClient.build
      @token_client = TravelClaim::TokenClient.new
    end

    ##
    # Returns a valid BTSSS v4 system access token for the given ICN.
    #
    # This method first checks the Redis cache for an existing valid token.
    # If no cached token exists, it obtains a fresh VEIS token and uses it
    # to request a new BTSSS v4 system access token, which is then cached.
    #
    # @param icn [String, nil] Patient's ICN. If nil, attempts to resolve from check_in_session
    # @return [String] Valid BTSSS v4 system access token
    # @raise [ArgumentError] If ICN cannot be resolved
    #
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

    ##
    # Requests fresh VEIS and BTSSS v4 tokens and returns both.
    #
    # This method mirrors the travel_pay module behavior by always requesting
    # fresh tokens and persisting them in Redis. It's useful when you need
    # both token types or want to ensure you have the latest tokens.
    #
    # @param icn [String, nil] Patient's ICN. If nil, attempts to resolve from check_in_session
    # @return [Hash] Hash containing both tokens: { veis_token: String, btsss_token: String }
    # @raise [ArgumentError] If ICN cannot be resolved
    #
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
