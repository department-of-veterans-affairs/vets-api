# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  class UserService < VAOS::BaseService
    def session(user)
      cached = cached_by_account_uuid(user.account_uuid)
      return cached.token if cached

      new_session_token(user)
    end

    def extend_session(account_uuid)
      unless session_creation_locked?(account_uuid)
        lock_session_creation(account_uuid)
        VAOS::ExtendSessionJob.perform_async(account_uuid)
      end
    end

    def update_session_token(account_uuid)
      cached = cached_by_account_uuid(account_uuid)
      if cached
        url = '/users/v2/session/jwts'
        response = perform(:get, url, nil, refresh_headers(account_uuid))
        new_token = response.body[:jws]
        Rails.logger.info('VAOS session updated',
                          {
                            account_uuid:,
                            new_jti: decoded_token(new_token)['jti'],
                            active_jti: decoded_token(cached.token)['jti']
                          })
        save_session!(account_uuid, new_token)
      else
        Rails.logger.warn('VAOS no session to update', account_uuid:)
      end
    rescue => e
      Rails.logger.error('VAOS session update failed', { account_uuid:, error: e.message })
      raise e
    end

    private

    def cached_by_account_uuid(account_uuid)
      SessionStore.find(account_uuid)
    end

    def redis_session_lock
      @redis ||= Redis::Namespace.new(REDIS_CONFIG[:va_mobile_session_refresh_lock][:namespace], redis: $redis)
    end

    def lock_session_creation(account_uuid)
      redis_session_lock.set(account_uuid, 1)
      redis_session_lock.expire(account_uuid, REDIS_CONFIG[:va_mobile_session_refresh_lock][:each_ttl])
    end

    def session_creation_locked?(account_uuid)
      !redis_session_lock.get(account_uuid).nil?
    end

    def save_session!(account_uuid, token)
      session_store = SessionStore.new(
        account_uuid:,
        token:,
        unix_created_at: Time.now.utc.to_i
      )
      session_store.save
      session_store.expire(ttl_duration_from_token(token))
      token
    end

    def new_session_token(user)
      url = '/users/v2/session?processRules=true'
      token = VAOS::JwtWrapper.new(user).token
      response = perform(:post, url, token, headers)
      raise Common::Exceptions::BackendServiceException.new('VAOS_502', source: self.class) unless body?(response)

      Rails.logger.info('VAOS session created',
                        { account_uuid: user.account_uuid, jti: decoded_token(token)['jti'] })

      lock_session_creation(user.account_uuid)
      save_session!(user.account_uuid, response.body)
    end

    def headers
      { 'Accept' => 'text/plain', 'Content-Type' => 'text/plain', 'Referer' => referrer }
    end

    def refresh_headers(account_uuid)
      {
        'Referer' => referrer,
        'X-VAMF-JWT' => cached_by_account_uuid(account_uuid).token,
        'X-Request-ID' => RequestStore.store['request_id']
      }
    end

    def ttl_duration_from_token(token)
      # token expiry with 45 second buffer to match SessionStore model TTL buffer
      Time.at(decoded_token(token)['exp']).utc.to_i - Time.now.utc.to_i - 45
    end

    def decoded_token(token)
      JWT.decode(token, nil, false).first
    end

    def body?(response)
      response&.body && response.body.present?
    end
  end
end
