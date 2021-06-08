# frozen_string_literal: true

require 'sentry_logging'

module TestUserDashboard
  class ApplicationController < ActionController::API
    include SentryLogging
    before_action :require_jwt

    def require_jwt
      token = request.headers['JWT']
      rsa_public = request.headers['PK']
      head :forbidden unless valid_token(token, rsa_public)
    end

    private

    def valid_token(token, rsa_public)
      return false unless token

      token.gsub!('Bearer ', '')
      begin
        JWT.decode token, rsa_public, true, { algorithm: 'RS256' }
        return true
      rescue JWT::DecodeError => e
        log_message_to_sentry('Error decoding TUD JWT: ', :error, body: e.message)
      end
      false
    end
  end
end
