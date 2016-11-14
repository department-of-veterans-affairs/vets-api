# frozen_string_literal: true
module Common
  module SessionBasedClient
    extend ActiveSupport::Concern

    attr_reader :config, :session

    def authenticate
      binding.pry
      if session.expired?
        session = get_session
        session.save
      end
      self
    end

    private

    def auth_headers
      config.base_request_headers.merge('appToken' => config.app_token, 'mhvCorrelationId' => session.user_id.to_s)
    end

    def token_headers
      config.base_request_headers.merge('Token' => session.token)
    end
  end
end
