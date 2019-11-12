# frozen_string_literal: true

module VAOS
  class UserService < Common::Client::Base
    configuration VAOS::UserConfiguration

    def session(user)
      cached = SessionStore.find(user.uuid)
      return cached.token if cached

      token = get_session_token(user)
      SessionStore.new(user_uuid: user.uuid, token: token).save
      token
    end

    private

    def get_session_token(user)
      url = '/users/v2/session?processRules=true'
      token = VAOS::JWT.new(user).token
      response = perform(:post, url, token)
      raise Common::Exceptions::BackendServiceException.new('VAOS_502', source: self.class) unless body?(response)

      response.body
    end

    def body?(response)
      response&.body && response.body.present?
    end
  end
end
