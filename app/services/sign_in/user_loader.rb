# frozen_string_literal: true

module SignIn
  class UserLoader
    CERNER_ELIGIBLE_COOKIE_NAME = 'CERNER_ELIGIBLE'

    attr_reader :access_token, :request_ip, :cookies

    def initialize(access_token:, request_ip:, cookies:)
      @access_token = access_token
      @request_ip = request_ip
      @cookies = cookies
    end

    def perform
      find_valid_user || reload_user
    end

    private

    def find_valid_user
      user = User.find(access_token.user_uuid)
      return unless user&.identity && user&.session_handle == access_token.session_handle

      user
    end

    def reload_user # rubocop:disable Metrics/MethodLength
      validate_account_and_session
      user_identity.uuid = access_token.user_uuid
      current_user.uuid = access_token.user_uuid
      current_user.last_signed_in = session.created_at
      current_user.fingerprint = request_ip
      current_user.session_handle = access_token.session_handle
      current_user.user_verification_id = user_verification.id
      current_user.save && user_identity.save
      current_user.invalidate_mpi_cache
      current_user.validate_mpi_profile
      current_user.create_mhv_account_async
      current_user.provision_cerner_async(source: :sis)
      set_cerner_eligibility_cookie

      context = {
        user_uuid: current_user.uuid,
        user_credentials:,
        credential_uuid: user_verification.credential_identifier,
        icn: user_account.icn,
        sign_in:
      }
      SignIn::Logger.new(prefix: self.class).info('reload_user', context)

      current_user
    end

    def validate_account_and_session
      raise Errors::SessionNotFoundError.new message: 'Invalid Session Handle' unless session
    end

    def set_cerner_eligibility_cookie
      cookies.permanent[CERNER_ELIGIBLE_COOKIE_NAME] = {
        value: current_user.cerner_eligible?,
        domain: IdentitySettings.sign_in.info_cookie_domain
      }
    end

    def user_attributes
      {
        mhv_icn: user_account.icn,
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
      { current: current_loa, highest: current_loa }
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
      [Constants::Auth::IDME, Constants::Auth::LOGINGOV].include?(sign_in[:service_name])
    end

    def user_is_verified?
      user_account.verified?
    end

    def session
      @session ||= OAuthSession.find_by(handle: access_token.session_handle)
    end

    def user_credentials
      @user_credentials ||= begin
        user_verifications = user_account.user_verifications
        {
          idme: user_verifications.idme.count,
          logingov: user_verifications.logingov.count
        }
      end
    end

    def user_account
      @user_account ||= session.user_account
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
