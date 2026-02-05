# frozen_string_literal: true

module SignIn
  module AuthSSO
    class SessionValidator
      def initialize(access_token:, client_id:)
        @access_token = access_token
        @client_id = client_id
      end

      def perform
        validate_session!
        validate_client_configs!
        validate_credential_level_and_type!

        auth_sso_user_attributes
      end

      private

      attr_reader :access_token, :client_id

      def auth_sso_user_attributes
        {
          idme_uuid: user_verification.idme_uuid || user_verification.backing_idme_uuid,
          logingov_uuid: user_verification.logingov_uuid,
          credential_email: session.credential_email,
          edipi: session_user_attributes[:edipi], 
          mhv_credential_uuid: user_verification.mhv_uuid,
          first_name: session_user_attributes[:first_name],
          last_name: session_user_attributes[:last_name],
          acr: session_assurance_level,
          type: user_verification.credential_type,
          icn: user_verification.user_account.icn,
          session_id: session.id
        }
      end

      def validate_session!
        unless access_token
          raise Errors::AccessTokenUnauthenticatedError.new(message: 'Access token is not authenticated')
        end
        raise Errors::SessionNotAuthorizedError.new(message: 'Session not authorized') unless session
      end

      def validate_client_configs!
        unless client_config.api_sso_enabled? && session_client_config.web_sso_enabled?
          raise Errors::InvalidClientConfigError.new message: 'SSO requested for client without shared sessions'
        end
      end

      def validate_credential_level_and_type!
        unless client_config.valid_credential_service_provider?(user_verification.credential_type)
          raise Errors::InvalidCredentialLevelError.new(message: 'Invalid credential service provider')
        end

        unless client_config.valid_service_level?(session_assurance_level)
          raise Errors::InvalidCredentialLevelError.new(message: 'Invalid service level')
        end
      end

      def client_config
        @client_config ||= ClientConfig.find_by(client_id:)
      end

      def user_verification
        @user_verification ||= session.user_verification
      end

      def session
        @session ||= OAuthSession.find_by(handle: access_token.session_handle)
      end

      def session_client_config
        @session_client_config ||= ClientConfig.find_by(client_id: session.client_id)
      end

      def session_user_attributes
        @session_user_attributes ||= session.user_attributes_hash
      end

      def session_assurance_level
        if user_verification.credential_type == Constants::Auth::LOGINGOV
          user_verification.verified? ? Constants::Auth::IAL2 : Constants::Auth::IAL1
        else
          user_verification.verified? ? Constants::Auth::LOA3 : Constants::Auth::LOA1
        end
      end
    end
  end
end
