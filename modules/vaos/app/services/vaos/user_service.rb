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
      url = "/users/v2/session"
      token = JWT.new(user).token
      response = perform(:post, url, token, {'Content-Type' => 'text/plain'})
      puts response
    rescue => e
      puts e.backtrace
      puts e.message
    end
  end
end
