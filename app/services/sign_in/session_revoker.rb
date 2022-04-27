# frozen_string_literal: true

module SignIn
  class SessionRevoker
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
      delete_session!
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

    def double_refresh_token_hash
      @double_refresh_token_hash ||= get_hash(refresh_token_hash)
    end

    def double_parent_refresh_token_hash
      @double_parent_refresh_token_hash ||= get_hash(refresh_token.parent_refresh_token_hash)
    end

    def refresh_token_hash
      @refresh_token_hash ||= get_hash(refresh_token.to_json)
    end

    def get_hash(object)
      Digest::SHA256.hexdigest(object)
    end

    def delete_session!
      session.destroy!
    end
  end
end
