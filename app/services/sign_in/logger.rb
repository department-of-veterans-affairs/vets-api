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

    def token_log(message, token, context = {})
      token_values = {
        user_uuid: token.user_uuid,
        session_id: token.session_handle,
        token_uuid: token&.uuid
      }
      context = context.merge(token_values)
      info(message, context)
    end
  end
end
