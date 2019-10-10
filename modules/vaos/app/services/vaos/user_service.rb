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
      url = "/users/v2/session?processRules=true"
      token = JWT.new(user).token
      perform(:post, url, token, {'Content-Type' => 'text/plain', 'Referer' => 'https://api.va.gov'})
    end
  end
end
