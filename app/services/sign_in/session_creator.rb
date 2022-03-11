# frozen_string_literal: true

module SignIn
  class SessionCreator
    attr_reader :user_account

    def initialize(user_account:)
      @user_account = user_account
    end

    def perform
      SessionContainer.new(session: session,
                           refresh_token: refresh_token,
                           access_token: access_token,
                           anti_csrf_token: anti_csrf_token)
    end

    private

    def anti_csrf_token
      @anti_csrf_token ||= SecureRandom.hex
    end

    def refresh_token
      @refresh_token ||= create_new_refresh_token(parent_refresh_token_hash: parent_refresh_token_hash)
    end

    def access_token
      @access_token ||= create_new_access_token
    end

    def session
      @session ||= create_new_session
    end

    def double_parent_refresh_token_hash
      @double_parent_refresh_token_hash ||= get_hash(parent_refresh_token_hash)
    end

    def refresh_token_hash
      @refresh_token_hash ||= get_hash(refresh_token.to_json)
    end

    def parent_refresh_token_hash
      @parent_refresh_token_hash ||= get_hash(create_new_refresh_token.to_json)
    end

    def create_new_access_token
      SignIn::AccessToken.new(
        session_handle: handle,
        user_uuid: user_account.id,
        refresh_token_hash: refresh_token_hash,
        parent_refresh_token_hash: parent_refresh_token_hash,
        anti_csrf_token: anti_csrf_token,
        last_regeneration_time: refresh_created_time
      )
    end

    def create_new_refresh_token(parent_refresh_token_hash: nil)
      SignIn::RefreshToken.new(
        session_handle: handle,
        user_uuid: user_account.id,
        parent_refresh_token_hash: parent_refresh_token_hash,
        anti_csrf_token: anti_csrf_token
      )
    end

    def create_new_session
      SignIn::OAuthSession.create!(user_account: user_account,
                                   handle: handle,
                                   hashed_refresh_token: double_parent_refresh_token_hash,
                                   refresh_expiration: refresh_expiration_time,
                                   refresh_creation: refresh_created_time)
    end

    def refresh_created_time
      @created_at ||= Time.zone.now
    end

    def refresh_expiration_time
      @expiration_at ||= Time.zone.now + Constants::RefreshToken::VALIDITY_LENGTH_MINUTES.minutes
    end

    def get_hash(object)
      Digest::SHA256.hexdigest(object)
    end

    def handle
      @handle ||= SecureRandom.uuid
    end
  end
end
