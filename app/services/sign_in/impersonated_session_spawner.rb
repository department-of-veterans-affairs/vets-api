# frozen_string_literal: true

require 'mpi/service'

module SignIn
  class ImpersonatedSessionSpawner
    include ActiveModel::Validations

    attr_reader :credential_email,
                :user_verification,
                :user_attributes,
                :client_config,
                :hashed_device_secret,
                :refresh_creation,
                :verified_user_account_icn

    validate :validate_credential_lock!,
             :validate_terms_of_use!

    def initialize(current_session:, client_config:, impersonated_user_verification:)
      @credential_email = impersonated_user_verification.user_credential_email.credential_email
      @user_verification = impersonated_user_verification
      @user_attributes = get_impersonated_user_attributes
      @client_config = client_config
      @hashed_device_secret = current_session.hashed_device_secret
      @refresh_creation = current_session.refresh_creation
      @verified_user_account_icn = current_session.user_account.icn
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
        last_regeneration_time: refresh_creation,
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
        hashed_device_secret:,
        verified_user_account_icn:
      )
    end

    def refresh_expiration_time
      @refresh_expiration_time ||= refresh_creation + client_config.refresh_token_duration
    end

    def get_hash(object)
      Digest::SHA256.hexdigest(object)
    end

    def get_impersonated_user_attributes
      response = MPI::Service.new.find_profile_by_identifier(identifier: user_verification.credential_identifier,
                                                             identifier_type: user_verification.credential_type).profile
      { first_name: response.given_names.first,
        last_name: response.family_name,
        email: user_verification.user_credential_email.credential_email }.to_json
    end

    def user_uuid
      @user_uuid ||= user_verification.backing_credential_identifier
    end

    def handle
      @handle ||= SecureRandom.uuid
    end
  end
end
