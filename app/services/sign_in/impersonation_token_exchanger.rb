# frozen_string_literal: true

module SignIn
  class ImpersonationTokenExchanger
    include ActiveModel::Validations

    attr_reader :subject_token, :subject_token_type, :actor_token, :actor_token_type, :client_id

    validate :validate_subject_token!,
             :validate_subject_token_type!,
             :validate_actor_token!,
             :validate_actor_token_type!,
             :validate_client_id!,
             :validate_impersonated_sessions_client!,
             :validate_user_account_delegations!

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

    def validate_actor_token!
      raise Errors::InvalidTokenError.new message: 'actor token is invalid' unless valid_actor_token?
    end

    def validate_actor_token_type!
      unless actor_token_type == Constants::Urn::JWT_TOKEN
        raise Errors::InvalidTokenTypeError.new message: 'actor token type is invalid'
      end
    end

    def validate_user_account_delegations!
      unless verified_user_account.delegated_accounts.include?(impersonated_user_verification.user_account)
        raise Errors::AccessDeniedError.new message: 'user account delegation not found'
      end
    end

    def valid_actor_token?
      decoded_actor_token['exp'] > Time.now.to_i && impersonated_user_verification
    end

    def verified_user_account
      @verified_user_account ||= UserAccount.find(current_session.user_account_id)
    end

    def impersonated_user_verification
      @impersonated_user_verification ||= UserVerification.find_by_type!(decoded_actor_token['type'],
                                                                         decoded_actor_token['sub'])
    end

    def decoded_actor_token
      @decoded_actor_token ||= JWT.decode(actor_token, public_key, true, algorithm: 'RS256').first
    end

    def public_key
      @public_key ||= private_key.public_key
    end

    def private_key
      @private_key ||= OpenSSL::PKey::RSA.new(File.read('spec/fixtures/sign_in/privatekey.pem'))
    end

    def validate_client_id!
      raise Errors::InvalidClientConfigError.new message: 'client configuration not found' unless client_config
    end

    def validate_impersonated_sessions_client!
      unless client_config.impersonated_sessions
        raise Errors::InvalidClientConfigError.new message: 'tokens requested for client without impersonated sessions'
      end
    end

    def create_new_session
      ImpersonatedSessionSpawner.new(current_session:, client_config:, impersonated_user_verification:).perform
    end

    def current_access_token
      @current_access_token ||= AccessTokenJwtDecoder.new(access_token_jwt: subject_token).perform
    end

    def current_session
      @current_session ||= OAuthSession.find_by(handle: current_access_token.session_handle)
    end

    def client_config
      @client_config ||= ClientConfig.find_by(client_id: current_access_token.client_id)
    end
  end
end
