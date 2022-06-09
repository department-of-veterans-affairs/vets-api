# frozen_string_literal: true

require 'sign_in/constants/auth'

module SignIn
  class Logger
    attr_reader :prefix

    def initialize(prefix:)
      @prefix = prefix
    end

    def info(message, context = {})
      Rails.logger.info("[SignInService] [#{prefix}] #{message}", context)
    end

    def access_token_log(message, token, context = {})
      token_values = {
        token_type: 'Access',
        user_id: token.user_uuid,
        session_id: token.session_handle,
        access_token_id: token.uuid
      }
      context = context.merge(token_values)
      info(message, context)
    end

    def refresh_token_log(message, token, context = {})
      token_values = {
        token_type: 'Refresh',
        user_id: token.user_uuid,
        session_id: token.session_handle
      }
      context = context.merge(token_values)
      info(message, context)
    end
  end
end
