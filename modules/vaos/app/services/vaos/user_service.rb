# frozen_string_literal: true

module VAOS
  class UserService < VAOS::BaseService
    def session
      cached = SessionStore.find(user.account_uuid)
      return cached.token if cached

      token = get_session_token
      session_store = SessionStore.new(account_uuid: user.account_uuid, token: token)
      session_store.save
      session_store.expire(get_ttl(token))

      token
    end

    private

    def headers
      { 'Accept' => 'text/plain', 'Content-Type' => 'text/plain', 'Referer' => referrer }
    end

    def get_session_token
      url = '/users/v2/session?processRules=true'
      token = VAOS::JWT.new(user).token
      response = perform(:post, url, token, headers)
      raise Common::Exceptions::BackendServiceException.new('VAOS_502', source: self.class) unless body?(response)

      response.body
    end

    def get_ttl(token)
      decoded_token = ::JWT.decode(token, nil, false).first
      # token expiry with 5 second buffer
      Time.at(decoded_token['exp']).utc.to_i - Time.now.utc.to_i - 5
    end

    def body?(response)
      response&.body && response.body.present?
    end
  end
end
