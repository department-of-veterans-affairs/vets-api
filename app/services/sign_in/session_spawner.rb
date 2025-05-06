# frozen_string_literal: true

module SignIn
  class SessionSpawner
    include ActiveModel::Validations

    attr_reader :credential_email,
                :user_verification,
                :user_attributes,
                :client_config,
                :hashed_device_secret,
                :refresh_creation

    validate :validate_credential_lock!,
             :validate_terms_of_use!

    def initialize(current_session:, new_session_client_config:)
      @credential_email = current_session.credential_email
      @user_verification = current_session.user_verification
      @user_attributes = current_session.user_attributes
      @client_config = new_session_client_config
      @hashed_device_secret = current_session.hashed_device_secret
      @refresh_creation = current_session.refresh_creation
    end

    def perform
      validate!

      SessionContainer.new(
        session: create_new_session,
        refresh_token:,
        access_token: create_new_access_token,
        anti_csrf_token:,
        client_config:
      )
    end

    private

    def validate_credential_lock!
      raise SignIn::Errors::CredentialLockedError.new message: 'Credential is locked' if user_verification.locked
    end

    def validate_terms_of_use!
      if client_config.enforced_terms.present? && user_verification.user_account.needs_accepted_terms_of_use?
        raise Errors::TermsOfUseNotAcceptedError.new message: 'Terms of Use has not been accepted'
      end
    end

    def anti_csrf_token
      @anti_csrf_token ||= SecureRandom.hex
    end

    def refresh_token
      @refresh_token ||= create_new_refresh_token(parent_refresh_token_hash:)
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
        client_id: client_config.client_id,
        user_uuid:,
        audience: AccessTokenAudienceGenerator.new(client_config:).perform,
        refresh_token_hash:,
        parent_refresh_token_hash:,
        anti_csrf_token:,
        last_regeneration_time:,
        user_attributes: JSON.parse(user_attributes)
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
      OAuthSession.create!(
        user_account: user_verification.user_account,
        user_verification:,
        client_id: client_config.client_id,
        credential_email:,
        handle:,
        hashed_refresh_token: double_parent_refresh_token_hash,
        refresh_expiration: refresh_expiration_time,
        refresh_creation:,
        user_attributes:,
        hashed_device_secret:
      )
    end

    def refresh_expiration_time
      @refresh_expiration_time ||= last_regeneration_time + client_config.refresh_token_duration
    end

    def last_regeneration_time
      @last_regeneration_time ||= Time.zone.now
    end

    def get_hash(object)
      Digest::SHA256.hexdigest(object)
    end

    def user_uuid
      @user_uuid ||= user_verification.backing_credential_identifier
    end

    def handle
      @handle ||= SecureRandom.uuid
    end
  end
end
