# frozen_string_literal: true

module VAOS
  class UserService < Common::Client::Base
    configuration VAOS::Configuration

    def session(user)
      cached = SessionStore.find(user.uuid)
      return cached.token if cached

      create_session(user)
    end

    private

    def create_session(user)
      url = '/users/v2/session?processRules=true'
      token = VAOS::JWT.new(user).token
      response = perform(:post, url, token, 'Content-Type' => 'text/plain', 'Referer' => 'https://api.va.gov')
      if response&.body
        SessionStore.new(user_uuid: user.uuid, token: response.body).save
        response.body
      end
    end
  end
end
