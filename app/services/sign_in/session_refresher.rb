# frozen_string_literal: true

module SignIn
  class SessionRefresher
    attr_reader :refresh_token, :anti_csrf_token, :enable_anti_csrf, :session

    def initialize(refresh_token:, anti_csrf_token:, enable_anti_csrf:)
      @refresh_token = refresh_token
      @anti_csrf_token = anti_csrf_token
      @enable_anti_csrf = enable_anti_csrf
    end

    def perform
      anti_csrf_check if enable_anti_csrf
      find_valid_oauth_session
      detect_token_theft
      update_session! if parent_refresh_token_in_session?
      create_new_tokens
    end

    private

    def anti_csrf_check
      raise SignIn::Errors::AntiCSRFMismatchError unless anti_csrf_token == refresh_token.anti_csrf_token
    end

    def find_valid_oauth_session
      @session ||= SignIn::OAuthSession.find_by(handle: refresh_token.session_handle)
      raise SignIn::Errors::SessionNotAuthorizedError unless session&.active?
    end

    def detect_token_theft
      raise SignIn::Errors::TokenTheftDetectedError unless refresh_token_in_session? || parent_refresh_token_in_session?
    end

    def refresh_token_in_session?
      session.hashed_refresh_token == double_refresh_token_hash
    end

    def parent_refresh_token_in_session?
      session.hashed_refresh_token == double_parent_refresh_token_hash
    end

    def create_new_tokens
      SessionContainer.new(session: session,
                           refresh_token: child_refresh_token,
                           access_token: access_token,
                           anti_csrf_token: updated_anti_csrf_token)
    end

    def update_session!
      session.hashed_refresh_token = double_refresh_token_hash
      session.refresh_expiration = refresh_expiration
      session.save!
    end

    def create_child_refresh_token
      SignIn::RefreshToken.new(
        session_handle: session.handle,
        user_uuid: session.user_account.id,
        anti_csrf_token: updated_anti_csrf_token,
        parent_refresh_token_hash: refresh_token_hash
      )
    end

    def create_access_token
      SignIn::AccessToken.new(
        session_handle: session.handle,
        user_uuid: session.user_account.id,
        refresh_token_hash: get_hash(child_refresh_token.to_json),
        parent_refresh_token_hash: refresh_token_hash,
        anti_csrf_token: updated_anti_csrf_token,
        last_regeneration_time: last_regeneration_time
      )
    end

    def last_regeneration_time
      @last_regeneration_time ||= Time.zone.now
    end

    def refresh_expiration
      @refresh_expiration ||= Time.zone.now + Constants::RefreshToken::VALIDITY_LENGTH_MINUTES.minutes
    end

    def updated_anti_csrf_token
      @updated_anti_csrf_token ||= SecureRandom.hex
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
