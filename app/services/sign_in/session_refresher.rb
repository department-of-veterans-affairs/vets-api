# frozen_string_literal: true

module SignIn
  class SessionRefresher
    attr_reader :refresh_token, :anti_csrf_token, :session

    def initialize(refresh_token:, anti_csrf_token:)
      @refresh_token = refresh_token
      @anti_csrf_token = anti_csrf_token
    end

    def perform
      find_valid_oauth_session
      anti_csrf_check if anti_csrf_enabled_client?
      detect_token_theft
      update_session! if parent_refresh_token_in_session?
      create_new_tokens
    end

    private

    def anti_csrf_check
      if anti_csrf_token != refresh_token.anti_csrf_token
        raise Errors::AntiCSRFMismatchError.new message: 'Anti CSRF token is not valid'
      end
    end

    def find_valid_oauth_session
      @session ||= OAuthSession.find_by(handle: refresh_token.session_handle)
      raise Errors::SessionNotAuthorizedError.new message: 'No valid Session found' unless session&.active?
    end

    def detect_token_theft
      unless refresh_token_in_session? || parent_refresh_token_in_session?
        session.destroy!
        raise Errors::TokenTheftDetectedError.new message: 'Token theft detected'
      end
    end

    def refresh_token_in_session?
      session.hashed_refresh_token == double_refresh_token_hash
    end

    def parent_refresh_token_in_session?
      session.hashed_refresh_token == double_parent_refresh_token_hash
    end

    def create_new_tokens
      SessionContainer.new(session:,
                           refresh_token: child_refresh_token,
                           access_token:,
                           client_config:,
                           anti_csrf_token: updated_anti_csrf_token)
    end

    def update_session!
      session.hashed_refresh_token = double_refresh_token_hash
      session.refresh_expiration = refresh_expiration
      session.save!
    end

    def create_child_refresh_token
      RefreshToken.new(
        session_handle: session.handle,
        user_uuid: refresh_token.user_uuid,
        anti_csrf_token: updated_anti_csrf_token,
        parent_refresh_token_hash: refresh_token_hash
      )
    end

    def create_access_token
      AccessToken.new(
        session_handle: session.handle,
        client_id: session.client_id,
        user_uuid: refresh_token.user_uuid,
        audience:,
        refresh_token_hash: get_hash(child_refresh_token.to_json),
        parent_refresh_token_hash: refresh_token_hash,
        anti_csrf_token: updated_anti_csrf_token,
        last_regeneration_time:
      )
    end

    def last_regeneration_time
      @last_regeneration_time ||= Time.zone.now
    end

    def refresh_expiration
      @refresh_expiration ||= Time.zone.now + validity_length
    end

    def validity_length
      client_config.refresh_token_duration
    end

    def updated_anti_csrf_token
      @updated_anti_csrf_token ||= SecureRandom.hex
    end

    def anti_csrf_enabled_client?
      client_config.anti_csrf
    end

    def audience
      @audience ||= client_config.access_token_audience
    end

    def client_config
      @client_config ||= SignIn::ClientConfig.find_by!(client_id: session.client_id)
    end

    def get_hash(object)
      Digest::SHA256.hexdigest(object)
    end

    def refresh_token_hash
      @refresh_token_hash ||= get_hash(refresh_token.to_json)
    end

    def double_refresh_token_hash
      @double_refresh_token_hash ||= get_hash(refresh_token_hash)
    end

    def double_parent_refresh_token_hash
      @double_parent_refresh_token_hash ||= get_hash(refresh_token.parent_refresh_token_hash)
    end

    def child_refresh_token
      @child_refresh_token ||= create_child_refresh_token
    end

    def access_token
      @access_token ||= create_access_token
    end
  end
end
