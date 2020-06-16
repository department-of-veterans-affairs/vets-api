# frozen_string_literal: true

module VAOS
  class UserService < VAOS::BaseService
    def session
      cached = SessionStore.find(user.account_uuid)
      return cached.token if cached

      token = get_session_token
      SessionStore.new(account_uuid: user.account_uuid, token: token).save
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
      raise Common::Exceptions::External::BackendServiceException.new('VAOS_502', source: self.class) unless body?(response)

      response.body
    end

    def body?(response)
      response&.body && response.body.present?
    end
  end
end
