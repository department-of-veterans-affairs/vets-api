# frozen_string_literal: true

require 'common/exceptions'
require 'map/security_token/service'

module VAOS
  class UserService < VAOS::BaseService
    def session(user)
      cached = cached_by_user_account_id(user.user_account_uuid)
      if cached && !expiring_soon?(cached.token)
        Rails.logger.info('VAOS token retrieved from cache',
                          { request_id: RequestStore.store['request_id'] })
        return cached.token
      end

      new_sts_session_token(user)
    end

    def update_session_token(user_account_id)
      cached = cached_by_user_account_id(user_account_id)
      if cached
        url = '/users/v2/session/jwts'
        response = perform(:get, url, nil, refresh_headers(user_account_id))
        new_token = response.body[:jws]
        Rails.logger.info('VAOS session updated',
                          {
                            user_account_id:,
                            new_jti: decoded_token(new_token)['jti'],
                            active_jti: decoded_token(cached.token)['jti']
                          })
        save_session!(user_account_id, new_token)
        new_token
      else
        Rails.logger.warn('VAOS no session to update', user_account_id:)
      end
    rescue => e
      Rails.logger.error('VAOS session update failed', { user_account_id:, error: e.message })
      raise e
    end

    private

    def cached_by_user_account_id(user_account_id)
      SessionStore.find(user_account_id)
    end

    def redis_session_lock
      @redis ||= Redis::Namespace.new(REDIS_CONFIG[:va_mobile_session_refresh_lock][:namespace], redis: $redis)
    end

    def lock_session_creation(user_account_id)
      redis_session_lock.set(user_account_id, 1)
      redis_session_lock.expire(user_account_id, REDIS_CONFIG[:va_mobile_session_refresh_lock][:each_ttl])
    end

    def save_session!(user_account_id, token)
      session_store = SessionStore.new(
        user_account_id:,
        token:,
        unix_created_at: Time.now.utc.to_i
      )
      session_store.save
      session_store.expire(ttl_duration_from_token(token))
    end

    # Creates a new session token using the Security Token Service (STS).
    #
    # This method first retrieves a new token from the STS. It then logs the creation of the session,
    # locks the session creation for the user, saves the session, and finally returns the token.
    #
    # @param user [User] The user for whom the session is being created.
    #
    # @return [String] The newly created session token.
    def new_sts_session_token(user)
      map_sts_rslt = MAP::SecurityToken::Service.new.token(application: :appointments, icn: user.icn)
      token = map_sts_rslt[:access_token]

      Rails.logger.info('VAOS session created with STS token',
                        {
                          user_account_id: user.user_account_uuid,
                          request_id: RequestStore.store['request_id'],
                          jti: decoded_token(token)['jti']
                        })

      lock_session_creation(user.user_account_uuid)
      save_session!(user.user_account_uuid, token)
      token
    end

    def headers
      { 'Accept' => 'text/plain', 'Content-Type' => 'text/plain', 'Referer' => referrer }
    end

    def refresh_headers(user_account_id)
      {
        'Referer' => referrer,
        'X-VAMF-JWT' => cached_by_user_account_id(user_account_id).token,
        'X-Request-ID' => RequestStore.store['request_id']
      }
    end

    def ttl_duration_from_token(token)
      # token expiry with 45 second buffer to match SessionStore model TTL buffer
      Time.at(decoded_token(token)['exp']).utc.to_i - Time.now.utc.to_i - 45
    end

    # Checks if a given JWT token is expiring soon.
    #
    # @param token [String] The JWT token to check.
    # @param leeway [Integer] The amount of time (in seconds) before the actual
    #   expiration time that should still be considered as "expiring soon". Default is 2 minutes.
    #
    # @return [Boolean] Returns true if the token is expiring soon (or if there was an error
    #   decoding the token), false otherwise.
    def expiring_soon?(token, leeway = 2.minutes)
      begin
        decoded_token = decoded_token(token)
      rescue JWT::DecodeError => e
        Rails.logger.error "VAOS Error decoding JWT: #{e}"
        return true
      end

      expiration_time = decoded_token['exp']

      expiration_time <= Time.now.to_i + leeway
    end

    def decoded_token(token)
      JWT.decode(token, nil, false).first
    end
  end
end
