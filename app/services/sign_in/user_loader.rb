# frozen_string_literal: true

module SignIn
  class UserLoader
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
      user = User.find(access_token.user_uuid)
      user&.identity ? user : nil
    end

    def reload_user
      validate_account_and_session
      user_identity.uuid = access_token.user_uuid
      current_user.uuid = access_token.user_uuid
      current_user.last_signed_in = session.created_at
      current_user.fingerprint = request_ip
      current_user.save && user_identity.save
      current_user
    end

    def validate_account_and_session
      raise Errors::SessionNotFoundError.new message: 'Invalid Session Handle' unless session
    end

    def user_attributes
      {
        mhv_icn: session.user_account.icn,
        idme_uuid: user_verification.idme_uuid || user_verification.backing_idme_uuid,
        logingov_uuid: user_verification.logingov_uuid,
        loa:,
        email: session.credential_email,
        authn_context:,
        multifactor:,
        sign_in:
      }
    end

    def loa
      current_loa = user_is_verified? ? Constants::Auth::LOA_THREE : Constants::Auth::LOA_ONE
      { current: current_loa, highest: Constants::Auth::LOA_THREE }
    end

    def sign_in
      { service_name: user_verification.credential_type,
        client_id: session.client_id,
        auth_broker: Constants::Auth::BROKER_CODE }
    end

    def authn_context
      case user_verification.credential_type
      when Constants::Auth::IDME
        user_is_verified? ? Constants::Auth::IDME_LOA3 : Constants::Auth::IDME_LOA1
      when Constants::Auth::DSLOGON
        user_is_verified? ? Constants::Auth::IDME_DSLOGON_LOA3 : Constants::Auth::IDME_DSLOGON_LOA1
      when Constants::Auth::MHV
        user_is_verified? ? Constants::Auth::IDME_MHV_LOA3 : Constants::Auth::IDME_MHV_LOA1
      when Constants::Auth::LOGINGOV
        user_is_verified? ? Constants::Auth::LOGIN_GOV_IAL2 : Constants::Auth::LOGIN_GOV_IAL1
      end
    end

    def multifactor
      user_is_verified? && idme_or_logingov_service
    end

    def idme_or_logingov_service
      sign_in[:service_name] == Constants::Auth::IDME || sign_in[:service_name] == Constants::Auth::LOGINGOV
    end

    def user_is_verified?
      session.user_account.verified?
    end

    def session
      @session ||= OAuthSession.find_by(handle: access_token.session_handle)
    end

    def user_verification
      @user_verification ||= session.user_verification
    end

    def user_identity
      @user_identity ||= UserIdentity.new(user_attributes)
    end

    def current_user
      return @current_user if @current_user

      user = User.new
      user.instance_variable_set(:@identity, user_identity)
      @current_user = user
    end
  end
end
