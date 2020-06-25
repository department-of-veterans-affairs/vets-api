# frozen_string_literal: true

module VAOS
  class UserService < VAOS::BaseService
    def session(user)
      cached = SessionStore.find(user.account_uuid)
      return cached.token if cached

      new_session_token(user)
    end

    def extend_session(account_uuid)
      cached = SessionStore.find(account_uuid)
      ExtendSession.perform_async(account_uuid) if cached && !recently_cached?(cached)
    end

    def update_session_token(account_uuid)
      url = '/users/v2/session/jwts'
      response = perform(:get, url, nil, refresh_headers)
      new_token = response.body[:jws]
      Rails.logger.info('VAOS session updated',
                        {
                          account_uuid: account_uuid,
                          new_jti: decoded_token(new_token)['jti'],
                          active_jti: decoded_token(cached.token)['jti']
                        })
      save_session!(account_uuid, new_token)
    end

    private

    def recently_cached?(cached)
      Time.now.utc.to_i - cached.unix_created_at < 15.seconds
    end

    def save_session!(account_uuid, token)
      session_store = SessionStore.new(
        account_uuid: account_uuid,
        token: token,
        unix_created_at: Time.now.utc.to_i
      )
      session_store.save
      session_store.expire(ttl_duration_from_token(token))
      token
    end

    def new_session_token(user)
      url = '/users/v2/session?processRules=true'
      token = VAOS::JWT.new(user).token
      response = perform(:post, url, token, headers)
      raise Common::Exceptions::BackendServiceException.new('VAOS_502', source: self.class) unless body?(response)

      Rails.logger.info('VAOS session created',
                        { account_uuid: user.account_uuid, jti: decoded_token(token)['jti'] })

      save_session!(user.account_uuid, response.body)
    end

    def headers
      { 'Accept' => 'text/plain', 'Content-Type' => 'text/plain', 'Referer' => referrer }
    end

    def refresh_headers
      { 'Referer' => referrer, 'X-VAMF-JWT' => cached.token, 'X-Request-ID' => RequestStore.store['request_id'] }
    end

    def ttl_duration_from_token(token)
      # token expiry with 5 second buffer
      Time.at(decoded_token(token)['exp']).utc.to_i - Time.now.utc.to_i - 5
    end

    def decoded_token(token)
      ::JWT.decode(token, nil, false).first
    end

    def body?(response)
      response&.body && response.body.present?
    end
  end
end
