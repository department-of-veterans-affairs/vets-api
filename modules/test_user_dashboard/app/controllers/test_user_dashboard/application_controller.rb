# frozen_string_literal: true

require 'sentry_logging'

module TestUserDashboard
  class ApplicationController < ActionController::API
    include SentryLogging
    before_action :require_jwt
    # SECRET = 'password123'

    def require_jwt
      # payload from example
      exp = Time.now.to_i + 300
      payload = { 'iss': 'tud.staging.va.gov',
                  'exp': exp,
                  'aud': '238d4793-70de-4183-9707-48ed8ecd19d9',
                  'sub': '19016b73-3ffa-4b26-80d8-aa9287738677' }
      token = JWT.encode payload, SECRET, 'HS256'

      head :forbidden unless valid_token(token)
    end

    private

    def valid_token(token)
      return false unless token

      token.gsub!('Bearer ', '')
      begin
        JWT.decode token, SECRET, true
        return true
      rescue JWT::DecodeError => e
        log_message_to_sentry('Error decoding TUD JWT: ', :error, body: e.message)
      end
      false
    end
  end
end
