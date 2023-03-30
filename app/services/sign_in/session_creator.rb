# frozen_string_literal: true

module SignIn
  class SessionCreator
    attr_reader :validated_credential

    def initialize(validated_credential:)
      @validated_credential = validated_credential
    end

    def perform
      SessionContainer.new(session:,
                           refresh_token:,
                           access_token:,
                           anti_csrf_token:,
                           client_config:)
    end

    private

    def anti_csrf_token
      @anti_csrf_token ||= SecureRandom.hex
    end

    def refresh_token
      @refresh_token ||= create_new_refresh_token(parent_refresh_token_hash:)
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
      AccessToken.new(
        session_handle: handle,
        client_id:,
        user_uuid:,
        audience:,
        refresh_token_hash:,
        parent_refresh_token_hash:,
        anti_csrf_token:,
        last_regeneration_time: refresh_created_time
      )
    end

    def create_new_refresh_token(parent_refresh_token_hash: nil)
      RefreshToken.new(
        session_handle: handle,
        user_uuid:,
        parent_refresh_token_hash:,
        anti_csrf_token:
      )
    end

    def create_new_session
      OAuthSession.create!(user_account:,
                           user_verification:,
                           client_id:,
                           credential_email:,
                           handle:,
                           hashed_refresh_token: double_parent_refresh_token_hash,
                           refresh_expiration: refresh_expiration_time,
                           refresh_creation: refresh_created_time)
    end

    def refresh_created_time
      @created_at ||= Time.zone.now
    end

    def refresh_expiration_time
      @expiration_at ||= Time.zone.now + validity_length
    end

    def get_hash(object)
      Digest::SHA256.hexdigest(object)
    end

    def client_id
      @client_id ||= client_config.client_id
    end

    def user_verification
      @user_verification ||= validated_credential.user_verification
    end

    def credential_email
      @credential_email ||= validated_credential.credential_email
    end

    def user_account
      @user_account ||= user_verification.user_account
    end

    def user_uuid
      @user_uuid ||= user_verification.backing_credential_identifier
    end

    def handle
      @handle ||= SecureRandom.uuid
    end

    def audience
      @audience ||= client_config.access_token_audience
    end

    def client_config
      @client_config ||= validated_credential.client_config
    end

    def validity_length
      client_config.refresh_token_duration
    end
  end
end
