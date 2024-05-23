# frozen_string_literal: true

module SignIn
  class TokenExchanger
    include ActiveModel::Validations

    attr_reader :subject_token, :subject_token_type, :actor_token, :actor_token_type, :client_id

    validates :subject_token, :subject_token_type, :actor_token, :actor_token_type, :client_id, presence: true
    validate :validate_subject_token, :validate_subject_token_type, :validate_actor_token_type, :validate_actor_token,
             :validate_client_id, :validate_device_sso_enabled

    def initialize(subject_token:, subject_token_type:, actor_token:, actor_token_type:, client_id:)
      @subject_token = subject_token
      @subject_token_type = subject_token_type
      @actor_token = actor_token
      @actor_token_type = actor_token_type
      @client_id = client_id
    end

    def perform
      validate!

      new_container = create_session_container
      Rails.logger.info('[SignIn::TokenExchanger] success',
                        { new_session: { handle: new_container.session.handle, context: to_h } })

      new_container
    rescue => e
      Rails.logger.error('[SignIn::TokenExchanger] error', message: e.message, context: to_h)
      raise Errors::TokenExchangerError.new(message: e.message)
    end

    private

    def create_session_container
      SessionContainer.new(session:, access_token:, refresh_token:, anti_csrf_token:, client_config:)
    end

    def session
      @session ||= OAuthSession.create!(user_account: current_session.user_account,
                                        user_verification: current_session.user_verification,
                                        credential_email: current_session.credential_email,
                                        hashed_device_secret: current_session.hashed_device_secret,
                                        user_attributes: current_user_attributes.to_json,
                                        refresh_creation: current_refresh_creation,
                                        client_id: client_config.client_id,
                                        handle: session_handle,
                                        hashed_refresh_token: hash_token(parent_refresh_token_hash),
                                        refresh_expiration:)
    end

    def access_token
      @access_token ||= AccessToken.new(session_handle:,
                                        refresh_token_hash:,
                                        parent_refresh_token_hash:,
                                        anti_csrf_token:,
                                        audience:,
                                        client_id: client_config.client_id,
                                        last_regeneration_time: current_refresh_creation,
                                        user_attributes: current_user_attributes,
                                        user_uuid: current_user_uuid)
    end

    def refresh_token
      @refresh_token ||= create_refresh_token(parent_refresh_token_hash)
    end

    def anti_csrf_token
      @anti_csrf_token ||= SecureRandom.hex
    end

    def create_refresh_token(parent_refresh_token_hash = nil)
      RefreshToken.new(session_handle:, parent_refresh_token_hash:, anti_csrf_token:, user_uuid: current_user_uuid)
    end

    def client_config
      @client_config ||= ClientConfig.find_by(client_id:)
    end

    def session_handle
      @session_handle ||= SecureRandom.uuid
    end

    def refresh_token_hash
      @refresh_token_hash ||= hash_token(refresh_token.to_json)
    end

    def parent_refresh_token_hash
      @parent_refresh_token_hash ||= hash_token(create_refresh_token.to_json)
    end

    def refresh_expiration
      @refresh_expiration ||= current_refresh_creation + client_config.refresh_token_duration
    end

    def audience
      @access_token_audience ||= AccessTokenAudienceGenerator.new(client_config:).perform
    end

    def current_access_token
      @current_access_token ||= AccessTokenJwtDecoder.new(access_token_jwt: subject_token).perform
    rescue
      nil
    end

    def current_session
      @current_session ||= OAuthSession.find_by(handle: current_access_token&.session_handle)
    end

    def current_refresh_creation
      @current_refresh_creation ||= current_session&.refresh_creation
    end

    def current_user_uuid
      @current_user_uuid ||= current_session.user_verification.backing_credential_identifier
    end

    def current_user_attributes
      @current_user_attributes ||= JSON.parse(current_session.user_attributes)
    end

    def current_client_config
      @current_client_config ||= ClientConfig.find_by(client_id: current_access_token&.client_id)
    end

    def device_sso
      @device_sso ||= current_client_config&.device_sso_enabled?
    end

    def hash_token(token)
      Digest::SHA256.hexdigest(token)
    end

    def to_h
      {
        subject_token:,
        subject_token_type:,
        actor_token:,
        actor_token_type:,
        client_id:
      }
    end

    def validate_subject_token
      return if subject_token.blank?

      errors.add(:subject_token, 'is not valid') if current_access_token.blank?
    end

    def validate_subject_token_type
      return if subject_token_type.blank?

      unless subject_token_type == Constants::AccessToken::OAUTH_TOKEN_TYPE
        errors.add(:subject_token_type, 'is not valid')
      end
    end

    def validate_actor_token_type
      return if actor_token_type.blank?

      errors.add(:actor_token_type, 'is not valid') unless actor_token_type == Constants::Auth::DEVICE_SECRET_TOKEN_TYPE
    end

    def validate_actor_token
      return if actor_token.blank?

      hashed_actor_token = hash_token(actor_token)

      mismatched = []
      mismatched << 'current_session' if hashed_actor_token != current_session&.hashed_device_secret
      mismatched << 'subject_token' if hashed_actor_token != current_access_token&.device_secret_hash

      errors.add(:actor_token, "does not match #{mismatched.join(' nor ')}") if mismatched.any?
    end

    def validate_client_id
      return if client_id.blank?

      errors.add(:client_id, 'is not valid') unless client_config&.client_id == Settings.sign_in.vaweb_client_id
    end

    def validate_device_sso_enabled
      errors.add(:device_sso, 'is not enabled') unless device_sso
    end
  end
end
