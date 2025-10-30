# frozen_string_literal: true

# This module only gets mixed in to one place, but is that cleanest way to organize everything in one place related
# to this responsibility alone.
module AuthenticationAndSSOConcerns # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern
  include ActionController::Cookies
  include SignIn::Authentication
  include SignIn::AudienceValidator

  included do
    before_action :authenticate, :set_session_expiration_header

    validates_access_token_audience [IdentitySettings.sign_in.vaweb_client_id,
                                     ('vamock' if MockedAuthentication.mockable_env?)]
  end

  protected

  def authenticate
    if cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME]
      super
    else
      validate_session || render_unauthorized
    end
  end

  def render_unauthorized
    raise Common::Exceptions::Unauthorized
  end

  def validate_inbound_login_params
    csp_type = params[:csp_type] ||= ''
    if csp_type == SAML::User::LOGINGOV_CSID
      ial = params[:ial]
      raise Common::Exceptions::ParameterMissing, 'ial' if ial.blank?
      raise Common::Exceptions::InvalidFieldValue.new('ial', ial) if %w[1 2].exclude?(ial)

      ial == '1' ? IAL::LOGIN_GOV_IAL1 : IAL::LOGIN_GOV_IAL2
    else
      authn = params[:authn]
      raise Common::Exceptions::ParameterMissing, 'authn' if authn.blank?
      raise Common::Exceptions::InvalidFieldValue.new('authn', authn) if SAML::User::AUTHN_CONTEXTS.keys.exclude?(authn)

      authn
    end
  end

  def validate_session
    load_user

    if @session_object.nil?
      Rails.logger.debug('SSO: INVALID SESSION', sso_logging_info)
      clear_session
      return false
    end

    extend_session!
    @current_user.present?
  end

  def load_user(skip_terms_check: false)
    if cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME]
      super()
    else
      set_session_object
      set_current_user(skip_terms_check)
    end
  end

  # Destroys the user's session in Redis
  def clear_session
    Rails.logger.debug('SSO: ApplicationController#clear_session', sso_logging_info)

    @session_object&.destroy
    @current_user&.destroy
    @session_object = nil
    @current_user = nil
  end

  # Destroys the users session in 1) Redis, 2) the MHV SSO Cookie, 3) and the Session Cookie
  def reset_session
    if Settings.test_user_dashboard.env == 'staging' && @current_user
      TestUserDashboard::UpdateUser.new(@current_user).call
      TestUserDashboard::AccountMetrics.new(@current_user).checkin
    end
    Rails.logger.info('SSO: ApplicationController#reset_session', sso_logging_info)

    clear_session
    super
  end

  # Extends the users session
  def extend_session!
    @session_object.expire(Session.redis_namespace_ttl)
    @current_user&.identity&.expire(UserIdentity.redis_namespace_ttl)
    @current_user&.expire(User.redis_namespace_ttl)
  end

  # Sets a cookie "api_session" with all of the key/value pairs from session object.
  def set_api_cookie
    return unless @session_object

    session.delete :value
    @session_object.to_hash.each { |k, v| session[k] = v }
  end

  def set_cerner_eligibility_cookie
    cookie_name = V1::SessionsController::CERNER_ELIGIBLE_COOKIE_NAME
    previous_value = cookies.signed[cookie_name]

    eligible = @current_user.cerner_eligible?

    cookies.signed.permanent[cookie_name] = {
      value: eligible,
      domain: IdentitySettings.sign_in.info_cookie_domain
    }

    Rails.logger.info('[SessionsController] Cerner Eligibility', eligible:, previous_value:, cookie_action: :set,
                                                                 icn: @current_user.icn)
  end

  def set_session_expiration_header
    headers['X-Session-Expiration'] = @session_object.ttl_in_time.httpdate if @session_object.present?
  end

  def log_sso_info
    action = "#{self.class}##{action_name}"

    Rails.logger.info(
      "#{action} request completed", sso_logging_info
    )
  end

  # Info for logging purposes related to SSO.
  def sso_logging_info
    { user_uuid: @current_user&.uuid,
      sso_cookie_contents: sso_cookie_content,
      request_host: request.host }
  end

  private

  def set_session_object
    @session_object = Session.find(session[:token])
  end

  def set_current_user(skip_terms_check)
    return unless @session_object

    user = User.find(@session_object.uuid) || reload_user
    if (skip_terms_check || !user&.needs_accepted_terms_of_use) && !user&.credential_lock && user&.identity
      @current_user = user
    end
  end

  def reload_user
    user_identity.uuid = @session_object.uuid
    reloaded_user.uuid = @session_object.uuid
    reloaded_user.last_signed_in = @session_object.created_at
    reloaded_user.fingerprint = request.ip
    reloaded_user.session_handle = @session_object.token
    reloaded_user.user_verification_id = user_verification.id
    reloaded_user.save && user_identity.save
    reloaded_user.invalidate_mpi_cache
    reloaded_user.validate_mpi_profile
    reloaded_user.create_mhv_account_async
    reloaded_user.provision_cerner_async(source: :ssoe)

    context = {
      user_uuid: reloaded_user.uuid,
      credential_uuid: user_verification.credential_identifier,
      icn: user_account.icn,
      sign_in:
    }
    Rails.logger.info('SSO: ApplicationController#reload_user', context)

    reloaded_user
  end

  def user_attributes
    {
      mhv_icn: user_account.icn,
      idme_uuid: user_verification.idme_uuid || user_verification.backing_idme_uuid,
      logingov_uuid: user_verification.logingov_uuid,
      loa:,
      email: user_verification.user_credential_email.credential_email,
      authn_context:,
      multifactor:,
      sign_in:
    }
  end

  def loa
    current_loa = user_is_verified? ? LOA::THREE : LOA::ONE
    { current: current_loa, highest: LOA::THREE }
  end

  def sign_in
    { service_name: user_verification.credential_type,
      client_id: IdentitySettings.sign_in.vaweb_client_id,
      auth_broker: SAML::URLService::BROKER_CODE }
  end

  def authn_context
    case user_verification.credential_type
    when SAML::User::IDME_CSID
      user_is_verified? ? LOA::IDME_LOA3 : LOA::IDME_LOA1_VETS
    when SAML::User::DSLOGON_CSID
      user_is_verified? ? LOA::IDME_DSLOGON_LOA3 : LOA::IDME_DSLOGON_LOA1
    when SAML::User::LOGINGOV_CSID
      user_is_verified? ? IAL::LOGIN_GOV_IAL2 : IAL::LOGIN_GOV_IAL1
    end
  end

  def multifactor
    user_is_verified? && idme_or_logingov_service
  end

  def idme_or_logingov_service
    [SAML::User::IDME_CSID, SAML::User::LOGINGOV_CSID].include?(sign_in[:service_name])
  end

  def user_is_verified?
    user_account.verified?
  end

  def sso_cookie_content
    return nil if @current_user.blank?

    { 'patientIcn' => @current_user.icn,
      'signIn' => @current_user.identity.sign_in.deep_transform_keys { |key| key.to_s.camelize(:lower) },
      'credential_used' => @current_user.identity.sign_in[:service_name],
      'credential_uuid' => credential_uuid,
      'session_uuid' => sign_in_service_session ? @access_token.session_handle : @session_object.token,
      'expirationTime' => sign_in_service_session ? sign_in_service_exp_time : @session_object.ttl_in_time.iso8601(0) }
  end

  def credential_uuid
    case @current_user.identity.sign_in[:service_name]
    when SAML::User::IDME_CSID
      @current_user.identity.idme_uuid
    when SAML::User::LOGINGOV_CSID
      @current_user.identity.logingov_uuid
    when SAML::User::DSLOGON_CSID
      @current_user.identity.edipi
    end
  end

  def sign_in_service_exp_time
    sign_in_service_session.refresh_expiration.iso8601(0)
  end

  def user_account
    @user_account ||= UserAccount.find(@session_object.uuid)
  end

  def user_verification
    @user_verification ||= UserVerification.find_by_type(SAML::User::IDME_CSID, @session_object.credential_uuid) ||
                           UserVerification.find_by_type(SAML::User::LOGINGOV_CSID, @session_object.credential_uuid)
  end

  def user_identity
    @user_identity ||= UserIdentity.new(user_attributes)
  end

  def reloaded_user
    return @reloaded_user if @reloaded_user

    user = User.new
    user.instance_variable_set(:@identity, user_identity)
    @reloaded_user = user
  end

  def sign_in_service_session
    return unless @access_token

    @sign_in_service_session ||= SignIn::OAuthSession.find_by(handle: @access_token.session_handle)
  end
end
