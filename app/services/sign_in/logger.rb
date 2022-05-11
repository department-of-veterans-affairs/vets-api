# frozen_string_literal: true

module SignIn
  class Logger
    def info_log(message, attributes = {})
      attributes[:timestamp] = Time.zone.now.to_s
      Rails.logger.info(message, attributes)
    end

    def access_token_log(message, token, attributes = {})
      token_values = {
        token_type: 'Access',
        user_id: token.user_uuid,
        session_id: token.session_handle,
        access_token_id: token.uuid
      }
      attributes = attributes.merge(token_values)
      info_log(message, attributes)
    end

    def refresh_token_log(message, token, attributes = {})
      token_values = {
        token_type: 'Refresh',
        user_id: token.user_uuid,
        session_id: token.session_handle
      }
      attributes = attributes.merge(token_values)
      info_log(message, attributes)
    end
  end
end
