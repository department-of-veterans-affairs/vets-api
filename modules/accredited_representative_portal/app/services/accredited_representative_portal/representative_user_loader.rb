# frozen_string_literal: true

module AccreditedRepresentativePortal
  class RepresentativeUserLoader
    attr_reader :access_token, :request_ip

    def initialize(access_token:, request_ip:)
      @access_token = access_token
      @request_ip = request_ip
    end

    def perform
      find_valid_user || reload_user
    end

    private

    def find_valid_user
      RepresentativeUser.find(access_token.user_uuid)
    end

    def reload_user
      validate_account_and_session
      current_user
    end

    def validate_account_and_session
      raise SignIn::Errors::SessionNotFoundError.new message: 'Invalid Session Handle' unless session
    end

    def loa
      current_loa = user_is_verified? ? SignIn::Constants::Auth::LOA_THREE : SignIn::Constants::Auth::LOA_ONE
      { current: current_loa, highest: SignIn::Constants::Auth::LOA_THREE }
    end

    def sign_in
      { service_name: user_verification.credential_type,
        client_id: session.client_id,
        auth_broker: SignIn::Constants::Auth::BROKER_CODE }
    end

    def authn_context
      case user_verification.credential_type
      when  SignIn::Constants::Auth::IDME
        user_is_verified? ?  SignIn::Constants::Auth::IDME_LOA3 : SignIn::Constants::Auth::IDME_LOA1
      when  SignIn::Constants::Auth::DSLOGON
        user_is_verified? ?  SignIn::Constants::Auth::IDME_DSLOGON_LOA3 : SignIn::Constants::Auth::IDME_DSLOGON_LOA1
      when  SignIn::Constants::Auth::MHV
        user_is_verified? ?  SignIn::Constants::Auth::IDME_MHV_LOA3 : SignIn::Constants::Auth::IDME_MHV_LOA1
      when  SignIn::Constants::Auth::LOGINGOV
        user_is_verified? ?  SignIn::Constants::Auth::LOGIN_GOV_IAL2 : SignIn::Constants::Auth::LOGIN_GOV_IAL1
      end
    end

    def user_is_verified?
      session.user_account.verified?
    end

    def session
      @session ||= SignIn::OAuthSession.find_by(handle: access_token.session_handle)
    end

    def user_verification
      @user_verification ||= session.user_verification
    end

    def current_user
      return @current_user if @current_user.present?

      user = RepresentativeUser.new
      user.uuid = access_token.user_uuid
      user.icn = session.user_account.icn
      user.email = session.credential_email
      user.first_name = session.user_attributes_hash['first_name']
      user.last_name = session.user_attributes_hash['last_name']
      user.fingerprint = request_ip
      user.authn_context = authn_context
      user.loa = loa
      user.logingov_uuid = user_verification.logingov_uuid
      user.idme_uuid = user_verification.idme_uuid || user_verification.backing_idme_uuid
      user.last_signed_in = session.created_at
      user.sign_in = sign_in
      user.save

      @current_user = user
    end
  end
end
