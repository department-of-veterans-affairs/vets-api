# frozen_string_literal: true

module SignIn
  class TokenExchanger
    include ActiveModel::Validations

    attr_reader :subject_token, :subject_token_type, :actor_token, :actor_token_type, :client_id

    validate :validate_subject_token!,
             :validate_subject_token_type!,
             :validate_actor_token!,
             :validate_actor_token_type!,
             :validate_client_id!,
             :validate_shared_sessions_client!,
             :validate_device_sso!

    def initialize(subject_token:, subject_token_type:, actor_token:, actor_token_type:, client_id:)
      @subject_token = subject_token
      @subject_token_type = subject_token_type
      @actor_token = actor_token
      @actor_token_type = actor_token_type
      @client_id = client_id
    end

    def perform
      validate!
      create_new_session
    end

    private

    def validate_subject_token!
      unless subject_token && current_access_token
        raise Errors::InvalidTokenError.new message: 'subject token is invalid'
      end
    end

    def validate_subject_token_type!
      unless subject_token_type == Constants::Urn::ACCESS_TOKEN
        raise Errors::InvalidTokenTypeError.new message: 'subject token type is invalid'
      end
    end

    def validate_actor_token_type!
      unless actor_token_type == Constants::Urn::DEVICE_SECRET
        raise Errors::InvalidTokenTypeError.new message: 'actor token type is invalid'
      end
    end

    def validate_actor_token!
      raise Errors::InvalidTokenError.new message: 'actor token is invalid' unless valid_actor_token?
    end

    def valid_actor_token?
      hashed_actor_token == current_session.hashed_device_secret &&
        hashed_actor_token == current_access_token.device_secret_hash
    end

    def hashed_actor_token
      @hashed_actor_token ||= Digest::SHA256.hexdigest(actor_token)
    end

    def validate_client_id!
      unless new_session_client_config
        raise Errors::InvalidClientConfigError.new message: 'client configuration not found'
      end
    end

    def validate_shared_sessions_client!
      unless new_session_client_config.shared_sessions
        raise Errors::InvalidClientConfigError.new message: 'tokens requested for client without shared sessions'
      end
    end

    def validate_device_sso!
      unless current_client_config.api_sso_enabled?
        raise Errors::InvalidSSORequestError.new message: 'token exchange requested from invalid client'
      end
    end

    def create_new_session
      SessionSpawner.new(current_session:, new_session_client_config:).perform
    end

    def new_session_client_config
      @new_session_client_config ||= ClientConfig.find_by(client_id:)
    end

    def current_access_token
      @current_access_token ||= AccessTokenJwtDecoder.new(access_token_jwt: subject_token).perform
    end

    def current_session
      @current_session ||= OAuthSession.find_by(handle: current_access_token.session_handle)
    end

    def current_client_config
      @current_client_config ||= ClientConfig.find_by(client_id: current_access_token.client_id)
    end
  end
end
