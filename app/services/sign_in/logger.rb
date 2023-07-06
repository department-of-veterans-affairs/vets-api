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
      token_values = if message == 'service_account token'
                       parsed_token = JWT.decode(token, nil, nil).first
                       { aud: parsed_token['aud'],
                         sub: parsed_token['sub'],
                         scopes: parsed_token['scopes'] }
                     else
                       { user_uuid: token.user_uuid,
                         session_id: token.session_handle,
                         token_uuid: token&.uuid }
                     end
      context = context.merge(token_values)
      info(message, context)
    end
  end
end
