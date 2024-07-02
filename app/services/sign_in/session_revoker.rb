# frozen_string_literal: true

require 'sign_in/logger'

module SignIn
  class SessionRevoker
    attr_reader :access_token, :refresh_token, :anti_csrf_token, :session, :device_secret

    def initialize(anti_csrf_token:, access_token: nil, refresh_token: nil, device_secret: nil)
      @refresh_token = refresh_token
      @anti_csrf_token = anti_csrf_token
      @access_token = access_token
      @device_secret = device_secret
    end

    def perform
      find_valid_oauth_session
      anti_csrf_check if anti_csrf_enabled_client?
      delete_session!
      delete_device_sessions if device_secret.present?
    end

    private

    def anti_csrf_check
      if anti_csrf_token != revoking_token.anti_csrf_token
        raise Errors::AntiCSRFMismatchError.new message: 'Anti CSRF token is not valid'
      end
    end

    def find_valid_oauth_session
      @session ||= OAuthSession.find_by(handle: revoking_token.session_handle)
      raise Errors::SessionNotAuthorizedError.new message: 'No valid Session found' unless session&.active?
    end

    def detect_token_theft
      unless refresh_token_in_session? || parent_refresh_token_in_session?
        raise Errors::TokenTheftDetectedError.new message: 'Token theft detected'
      end
    end

    def refresh_token_in_session?
      session.hashed_refresh_token == double_refresh_token_hash
    end

    def parent_refresh_token_in_session?
      session.hashed_refresh_token == double_parent_refresh_token_hash
    end

    def double_refresh_token_hash
      @double_refresh_token_hash ||= get_hash(refresh_token_hash)
    end

    def double_parent_refresh_token_hash
      @double_parent_refresh_token_hash ||= get_hash(refresh_token.parent_refresh_token_hash)
    end

    def refresh_token_hash
      @refresh_token_hash ||= get_hash(refresh_token.to_json)
    end

    def revoking_token
      @revoking_token ||= access_token || refresh_token
    end

    def client_config
      @client_config ||= SignIn::ClientConfig.find_by!(client_id: session.client_id)
    end

    def anti_csrf_enabled_client?
      client_config.anti_csrf
    end

    def get_hash(object)
      Digest::SHA256.hexdigest(object)
    end

    def delete_session!
      detect_token_theft if refresh_token
    ensure
      session.destroy!
    end

    def delete_device_sessions
      hashed_device_secret = get_hash(device_secret)
      OAuthSession.where(hashed_device_secret:).destroy_all
    end
  end
end
