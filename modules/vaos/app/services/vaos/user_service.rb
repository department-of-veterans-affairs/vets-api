# frozen_string_literal: true

module VAOS
  class UserService < VAOS::BaseService
    def session
      cached = SessionStore.find(user.account_uuid)
      return save_session(new_session_token) unless cached
      return save_session(update_session_token(cached.token)) if expires_in_two_minutes?(cached.ttl)

      cached.token
    end

    private

    def expires_in_two_minutes?(ttl)
      ttl < 60 * 5
    end

    def save_session(token)
      session_store = SessionStore.new(account_uuid: user.account_uuid, token: token)
      session_store.save
      session_store.expire(ttl_duration_from_token(token))
      token
    end

    def new_session_token
      url = '/users/v2/session?processRules=true'
      token = VAOS::JWT.new(user).token
      response = perform(:post, url, token, headers)
      raise Common::Exceptions::BackendServiceException.new('VAOS_502', source: self.class) unless body?(response)

      log('created', jti: decoded_token(token)['jti'])
      response.body
    end

    def update_session_token(active_token)
      url = '/users/v2/session/jwts'
      response = perform(:get, url, nil, refresh_headers(active_token))
      new_token = response.body[:jws]
      log('updated', { new_jti: decoded_token(new_token)['jti'], active_jti: decoded_token(active_token)['jti'] })
      new_token
    end

    def headers
      { 'Accept' => 'text/plain', 'Content-Type' => 'text/plain', 'Referer' => referrer }
    end

    def refresh_headers(active_token)
      { 'Referer' => referrer, 'X-VAMF-JWT' => active_token, 'X-Request-ID' => RequestStore.store['request_id'] }
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

    def log(event, details)
      Rails.logger.info("VAOS session #{event}", details.merge({ user_uuid: @user.uuid }))
    end
  end
end
