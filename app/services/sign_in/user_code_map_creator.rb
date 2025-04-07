# frozen_string_literal: true

module SignIn
  class UserCodeMapCreator
    attr_reader :state_payload,
                :idme_uuid,
                :logingov_uuid,
                :credential_email,
                :all_credential_emails,
                :verified_icn,
                :edipi,
                :mhv_credential_uuid,
                :request_ip,
                :first_name,
                :last_name,
                :web_sso_session_id

    def initialize(user_attributes:, state_payload:, verified_icn:, request_ip:)
      @state_payload = state_payload
      @idme_uuid = user_attributes[:idme_uuid]
      @logingov_uuid = user_attributes[:logingov_uuid]
      @credential_email = user_attributes[:csp_email]
      @all_credential_emails = user_attributes[:all_csp_emails]
      @edipi = user_attributes[:edipi]
      @mhv_credential_uuid = user_attributes[:mhv_credential_uuid]
      @verified_icn = verified_icn
      @request_ip = request_ip
      @first_name = user_attributes[:first_name]
      @last_name = user_attributes[:last_name]
      @web_sso_session_id = user_attributes[:session_id]
    end

    def perform
      create_credential_email
      create_user_acceptable_verified_credential
      create_terms_code_container if needs_accepted_terms_of_use?
      create_code_container

      user_code_map
    end

    private

    def create_credential_email
      Login::UserCredentialEmailUpdater.new(credential_email:,
                                            user_verification:).perform
    end

    def create_user_acceptable_verified_credential
      Login::UserAcceptableVerifiedCredentialUpdater.new(user_account:).perform
    end

    def create_terms_code_container
      TermsCodeContainer.new(code: terms_code, user_account_uuid: user_account.id).save!
    end

    def create_code_container
      CodeContainer.new(code: login_code,
                        client_id: state_payload.client_id,
                        code_challenge: state_payload.code_challenge,
                        user_verification_id: user_verification.id,
                        credential_email:,
                        user_attributes: access_token_attributes,
                        device_sso:,
                        web_sso_session_id:).save!
    end

    def device_sso
      state_payload.scope == Constants::Auth::DEVICE_SSO
    end

    def user_code_map
      @user_code_map ||= UserCodeMap.new(login_code:,
                                         type: state_payload.type,
                                         client_state: state_payload.client_state,
                                         client_config:,
                                         terms_code:)
    end

    def user_verification
      @user_verification ||= Login::UserVerifier.new(login_type: sign_in[:service_name],
                                                     auth_broker: sign_in[:auth_broker],
                                                     mhv_uuid: mhv_credential_uuid,
                                                     idme_uuid:,
                                                     dslogon_uuid: edipi,
                                                     logingov_uuid:,
                                                     icn: verified_icn).perform
    end

    def user_account
      @user_account ||= user_verification.user_account
    end

    def sign_in
      @sign_in ||= {
        service_name: state_payload.type,
        auth_broker: Constants::Auth::BROKER_CODE,
        client_id: state_payload.client_id
      }
    end

    def user_uuid
      @user_uuid ||= user_verification.backing_credential_identifier
    end

    def access_token_attributes
      { first_name:,
        last_name:,
        email: credential_email,
        all_emails: all_credential_emails }.compact
    end

    def needs_accepted_terms_of_use?
      client_config.va_terms_enforced? && user_account.needs_accepted_terms_of_use?
    end

    def client_config
      @client_config ||= SignIn::ClientConfig.find_by!(client_id: state_payload.client_id)
    end

    def login_code
      @login_code ||= SecureRandom.uuid
    end

    def terms_code
      return nil unless needs_accepted_terms_of_use?

      @terms_code ||= SecureRandom.uuid
    end
  end
end
