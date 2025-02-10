# frozen_string_literal: true

require 'sentry_logging'

module TestUserDashboard
  class ApplicationController < ActionController::API
    include SentryLogging
    include Traceable

    def require_jwt
      token = request.headers['JWT']
      pub_key = request.headers['PK']

      head :forbidden unless valid_token(token, pub_key)
    end

    private

    def valid_token(token, pub_key)
      return false unless token && pub_key

      rsa_public = OpenSSL::PKey::RSA.new(Base64.decode64(pub_key))
      raw_token = token.gsub('Bearer ', '')
      begin
        JWT.decode raw_token, rsa_public, true, { algorithm: 'RS256' }
        return true
      rescue JWT::DecodeError => e
        log_message_to_sentry('Error decoding TUD JWT: ', :error, body: e.message)
      end
      false
    end

    def set_sentry_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'test-user-dashboard' }
      Sentry.set_tags(source: 'test-user-dashboard')
    end
  end
end
