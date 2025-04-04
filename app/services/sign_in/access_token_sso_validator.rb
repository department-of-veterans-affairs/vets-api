# frozen_string_literal: true

module SignIn
  class AccessTokenSSOValidator
    attr_reader :access_token, :client_config

    def initialize(access_token:, client_config:)
      @access_token = access_token
      @client_config = client_config
    end

    def perform
      validate_session!
      validate_shared_sessions!
      validate_credential_level_and_type!

      sso_validator_attributes
    end

    private

    def validate_session!
      raise Errors::AccessTokenUnauthenticatedError.new message: 'Access token invalid' unless access_token
      raise Errors::SessionNotFoundError.new message: 'Session not found' unless session
    end

    def validate_shared_sessions!
      unless client_config.api_sso_enabled? && current_session_client_config.web_sso_server_enabled?
        raise Errors::InvalidClientConfigError.new message: 'SSO requested for client without shared sessions'
      end
    end

    def validate_credential_level_and_type!
      unless client_config.valid_service_level?(session_assurance_level)
        raise Errors::InvalidClientConfigError.new message: 'SSO requested for session with excluded assurance level'
      end
      unless client_config.valid_credential_service_provider?(user_verification.credential_type)
        raise Errors::InvalidClientConfigError.new message: 'SSO requested for session with excluded service provider'
      end
    end

    def session_assurance_level
      if user_verification.credential_type == Constants::Auth::LOGINGOV
        user_verification.verified? ? Constants::Auth::IAL2 : Constants::Auth::IAL1
      else
        user_verification.verified? ? Constants::Auth::LOA3 : Constants::Auth::LOA1
      end
    end

    def sso_validator_attributes
      {
        idme_uuid: user_verification.idme_uuid || user_verification.backing_idme_uuid,
        logingov_uuid: user_verification.logingov_uuid,
        credential_email: session.credential_email,
        edipi: user_verification.dslogon_uuid,
        mhv_credential_uuid: user_verification.mhv_uuid,
        first_name: session_user_attributes[:first_name],
        last_name: session_user_attributes[:last_name],
        acr: session_assurance_level,
        type: user_verification.credential_type,
        icn: user_verification.user_account.icn,
        session_id: session.id
      }
    end

    def user_verification
      @user_verification ||= session.user_verification
    end

    def session_user_attributes
      @session_user_attributes ||= session.user_attributes_hash
    end

    def current_session_client_config
      @current_session_client_config ||= ClientConfig.find_by(client_id: session.client_id)
    end

    def session
      @session ||= SignIn::OAuthSession.find_by(handle: access_token.session_handle)
    end
  end
end
