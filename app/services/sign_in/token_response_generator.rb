# frozen_string_literal: true

require 'user_audit_logger'

module SignIn
  class TokenResponseGenerator
    attr_reader :grant_type, :code, :code_verifier, :client_assertion, :client_assertion_type, :assertion,
                :subject_token, :subject_token_type, :actor_token, :actor_token_type, :client_id, :cookies,
                :request_attributes

    def initialize(params:, cookies:, request_attributes:)
      @grant_type = params[:grant_type]
      @code = params[:code]
      @code_verifier = params[:code_verifier]
      @client_assertion = params[:client_assertion]
      @client_assertion_type = params[:client_assertion_type]
      @assertion = params[:assertion]
      @subject_token = params[:subject_token]
      @subject_token_type = params[:subject_token_type]
      @actor_token = params[:actor_token]
      @actor_token_type = params[:actor_token_type]
      @client_id = params[:client_id]
      @cookies = cookies
      @request_attributes = request_attributes
    end

    def perform
      case grant_type
      when Constants::Auth::AUTH_CODE_GRANT
        generate_client_tokens
      when Constants::Auth::JWT_BEARER_GRANT
        generate_service_account_token
      when Constants::Auth::TOKEN_EXCHANGE_GRANT
        generate_token_exchange_response
      else
        raise Errors::MalformedParamsError.new(message: 'Grant type is not valid')
      end
    end

    private

    def generate_client_tokens
      validated_credential = CodeValidator.new(code:, code_verifier:, client_assertion:,
                                               client_assertion_type:).perform
      session_container = SessionCreator.new(validated_credential:).perform

      create_user_audit_log(user_verification: validated_credential.user_verification)
      sign_in_logger.info('session created', session_container.access_token.to_s)

      TokenSerializer.new(session_container:, cookies:).perform
    end

    def generate_service_account_token
      service_account_access_token = AssertionValidator.new(assertion:).perform
      sign_in_logger.info('generated service account token', service_account_access_token.to_s)

      encoded_access_token = ServiceAccountAccessTokenJwtEncoder.new(service_account_access_token:).perform

      serialized_service_account_token(access_token: encoded_access_token)
    end

    def generate_token_exchange_response
      exchanged_container = TokenExchanger.new(subject_token:, subject_token_type:, actor_token:,
                                               actor_token_type:, client_id:).perform

      sign_in_logger.info('token exchanged', exchanged_container.access_token.to_s)

      TokenSerializer.new(session_container: exchanged_container, cookies:).perform
    end

    def sign_in_logger
      @sign_in_logger ||= Logger.new(prefix: self.class)
    end

    def serialized_service_account_token(access_token:)
      {
        data: {
          access_token:
        }
      }
    end

    def create_user_audit_log(user_verification:)
      UserAuditLogger.new(user_action_event_identifier: 'sign_in',
                          subject_user_verification: user_verification,
                          status: :success,
                          acting_ip_address: request_attributes[:remote_ip],
                          acting_user_agent: request_attributes[:user_agent]).perform
    end
  end
end
