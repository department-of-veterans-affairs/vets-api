# frozen_string_literal: true

require 'sentry_logging'

module TestUserDashboard
  class ApplicationController < ActionController::API
    include SentryLogging
    before_action :require_jwt

    def require_jwt
      # payload from example
      payload = { data: 'test' }
      rsa_private = OpenSSL::PKey::RSA.generate 2048
      rsa_public = rsa_private.public_key
      token = JWT.encode payload, rsa_private, 'RS256'
      # token = JWT.encode payload, nil, 'none'

      head :forbidden unless valid_token(token, rsa_public)
    end

    private

    def valid_token(token, rsa_public)
      return false unless token

      token.gsub!('Bearer ', '')
      begin
        JWT.decode token, rsa_public, true, { algorithm: 'RS256' }
        # JWT.decode token, nil, false
        return true
      rescue JWT::DecodeError => e
        log_message_to_sentry('Error decoding TUD JWT: ', :error, body: e.message)
      end
      false
    end
  end
end
