# frozen_string_literal: true

module AccreditedRepresentativePortal
  class RepresentativeUserCreator
    attr_reader :state_payload,
                :idme_uuid,
                :logingov_uuid,
                :authn_context,
                :current_ial,
                :max_ial,
                :credential_email,
                :multifactor,
                :verified_icn,
                :edipi,
                :mhv_correlation_id,
                :request_ip,
                :first_name,
                :last_name

    def initialize(user_attributes:, state_payload:, verified_icn:, request_ip:)
      @state_payload = state_payload
      @idme_uuid = user_attributes[:idme_uuid]
      @logingov_uuid = user_attributes[:logingov_uuid]
      @authn_context = user_attributes[:authn_context]
      @current_ial = user_attributes[:current_ial]
      @max_ial = user_attributes[:max_ial]
      @credential_email = user_attributes[:csp_email]
      @multifactor = user_attributes[:multifactor]
      @edipi = user_attributes[:edipi]
      @mhv_correlation_id = user_attributes[:mhv_correlation_id]
      @verified_icn = verified_icn
      @request_ip = request_ip
      @first_name = user_attributes[:first_name]
      @last_name = user_attributes[:last_name]
    end

    def perform
      create_authenticated_user
      create_credential_email
      create_user_acceptable_verified_credential
      create_code_container
      user_code_map
    end

    private

    def create_authenticated_user
      user
    end

    def create_credential_email
      Login::UserCredentialEmailUpdater.new(credential_email:,
                                            user_verification:).perform
    end

    def create_user_acceptable_verified_credential
      Login::UserAcceptableVerifiedCredentialUpdater.new(user_account: user_verification.user_account).perform
    end

    def create_code_container
      SignIn::CodeContainer.new(code: login_code,
                                client_id: state_payload.client_id,
                                code_challenge: state_payload.code_challenge,
                                user_verification_id: user_verification.id,
                                credential_email:,
                                user_attributes: access_token_attributes).save!
    end

    def user_verifier_object
      @user_verifier_object ||= OpenStruct.new({ idme_uuid:,
                                                 logingov_uuid:,
                                                 sign_in:,
                                                 edipi:,
                                                 mhv_correlation_id:,
                                                 icn: verified_icn })
    end

    def user_code_map
      @user_code_map ||= SignIn::UserCodeMap.new(login_code:,
                                                 type: state_payload.type,
                                                 client_state: state_payload.client_state,
                                                 client_config:,
                                                 terms_code: nil)
    end

    def user_verification
      @user_verification ||= Login::UserVerifier.new(user_verifier_object).perform
    end

    def sign_in
      @sign_in ||= {
        service_name: state_payload.type,
        auth_broker: SignIn::Constants::Auth::BROKER_CODE,
        client_id: state_payload.client_id
      }
    end

    def loa
      @loa ||= { current: ial_to_loa(current_ial), highest: ial_to_loa(max_ial) }
    end

    def ial_to_loa(ial)
      ial == SignIn::Constants::Auth::IAL_TWO ? SignIn::Constants::Auth::LOA_THREE : SignIn::Constants::Auth::LOA_ONE
    end

    def user_uuid
      @user_uuid ||= user_verification.backing_credential_identifier
    end

    def access_token_attributes
      { first_name:,
        last_name:,
        email: credential_email }.compact
    end

    def client_config
      @client_config ||= SignIn::ClientConfig.find_by!(client_id: state_payload.client_id)
    end

    def login_code
      @login_code ||= SecureRandom.uuid
    end

    def user
      @user ||= begin
        user = RepresentativeUser.new
        user.uuid = user_uuid
        user.icn = verified_icn
        user.email = credential_email
        user.idme_uuid = idme_uuid
        user.logingov_uuid = logingov_uuid
        user.first_name = first_name
        user.last_name = last_name
        user.fingerprint = request_ip
        user.last_signed_in = Time.zone.now
        user.authn_context = authn_context
        user.loa = loa
        user.sign_in = sign_in
        user.save
      end
    end
  end
end
