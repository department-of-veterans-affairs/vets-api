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

      response.body
    end

    def update_session_token(session_token)
      url = '/users/v2/session/jwts'
      response = perform(:get, url, nil, refresh_headers(session_token))
      response.body[:jws]
    end

    def headers
      { 'Accept' => 'text/plain', 'Content-Type' => 'text/plain', 'Referer' => referrer }
    end

    def refresh_headers(session_token)
      { 'Referer' => referrer, 'X-VAMF-JWT' => session_token, 'X-Request-ID' => RequestStore.store['request_id'] }
    end

    def ttl_duration_from_token(token)
      decoded_token = ::JWT.decode(token, nil, false).first
      # token expiry with 5 second buffer
      Time.at(decoded_token['exp']).utc.to_i - Time.now.utc.to_i - 5
    end

    def body?(response)
      response&.body && response.body.present?
    end
  end
end
