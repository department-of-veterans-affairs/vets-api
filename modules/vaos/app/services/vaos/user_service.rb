# frozen_string_literal: true

module VAOS
  class UserService < Common::Client::Base
    configuration VAOS::Configuration

    def session(user)
      url = "/users/v2/session"
      token = JWT.new(user).token
      perform(:post, url, token, {'Content-Type' => 'text/plain'})
    end
  end
end
