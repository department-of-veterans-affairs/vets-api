# frozen_string_literal: true

# This module only gets mixed in to one place, but is that cleanest way to organize everything in one place related
# to this responsibility alone.
# rubocop:disable Metrics/ModuleLength
module AuthenticationAndSSOConcerns
  extend ActiveSupport::Concern
  include ActionController::Cookies

  included do
    before_action :authenticate
    before_action :set_session_expiration_header
  end

  protected

  def authenticate
    validate_session || render_unauthorized
  end

  def render_unauthorized
    raise Common::Exceptions::Unauthorized
  end

  def validate_session
    load_user

    if @session_object.nil?
      Rails.logger.debug('SSO: INVALID SESSION', sso_logging_info)
      clear_session
      return false
    end

    if should_signout_sso?
      Rails.logger.info('SSO: MHV INITIATED SIGNOUT', sso_logging_info)
      reset_session
    else
      extend_session!
    end

    @current_user.present?
  end

  def load_user
    @session_object = Session.find(session[:token])
    @current_user = User.find(@session_object.uuid) if @session_object&.uuid
  end

  # Destroys the user's session in Redis and the MHV SSO Cookie
  def clear_session
    Rails.logger.debug('SSO: ApplicationController#clear_session', sso_logging_info)

    cookies.delete(Settings.sso.cookie_name, domain: Settings.sso.cookie_domain)
    @session_object&.destroy
    @current_user&.destroy
    @session_object = nil
    @current_user = nil
  end

  # Destroys the users session in 1) Redis, 2) the MHV SSO Cookie, 3) and the Session Cookie
  def reset_session
    if Settings.test_user_dashboard.env == 'staging'
      AfterLogoutJob.perform_async(account_uuid: @current_user&.account_uuid)
    end
    Rails.logger.info('SSO: ApplicationController#reset_session', sso_logging_info)

    clear_session
    super
  end

  # Determines whether user signed out of MHV's website
  def should_signout_sso?
    # TODO: This logic needs updating to let us log out either/or
    # SSOe session or MHV-SSO session but for  now  the next line lets
    # us avoid terminating  the session due to not setting it  previously
    return false if @session_object&.authenticated_by_ssoe
    return false unless Settings.sso.cookie_enabled && Settings.sso.cookie_signout_enabled

    cookies[Settings.sso.cookie_name].blank? && request.host.match(Settings.sso.cookie_domain)
  end

  # Extends the users session, including the MHV SSO Cookie
  def extend_session!
    @session_object.expire(Session.redis_namespace_ttl)
    @current_user&.identity&.expire(UserIdentity.redis_namespace_ttl)
    @current_user&.expire(User.redis_namespace_ttl)
    set_sso_cookie!
  end

  # Sets a cookie "api_session" with all of the key/value pairs from session object.
  def set_api_cookie!
    return unless @session_object

    session.delete :value
    @session_object.to_hash.each { |k, v| session[k] = v }
  end

  # Sets a cookie used by MHV for SSO
  def set_sso_cookie!
    return unless Settings.sso.cookie_enabled &&
                  @session_object.present? &&
                  # if the user logged in via SSOe, there is no benefit from
                  # creating a MHV SSO shared cookie
                  !@session_object&.authenticated_by_ssoe

    Rails.logger.info('SSO: ApplicationController#set_sso_cookie!', sso_logging_info)

    encryptor = SSOEncryptor
    encrypted_value = encryptor.encrypt(ActiveSupport::JSON.encode(sso_cookie_content))
    cookies[Settings.sso.cookie_name] = {
      value: encrypted_value,
      expires: nil, # NOTE: we track expiration as an attribute in "value." nil here means kill cookie on browser close.
      secure: Settings.sso.cookie_secure,
      httponly: true,
      domain: Settings.sso.cookie_domain
    }
  end

  def set_session_expiration_header
    headers['X-Session-Expiration'] = @session_object.ttl_in_time.httpdate if @session_object.present?
  end

  # The contents of MHV SSO Cookie with specifications found here:
  # https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/SSO/CookieSpecs-20180906.docx
  def sso_cookie_content
    return nil if @current_user.blank?

    {
      'patientIcn' => (@current_user.mhv_icn || @current_user.icn),
      'mhvCorrelationId' => @current_user.mhv_correlation_id,
      'signIn' => @current_user.identity.sign_in.deep_transform_keys { |key| key.to_s.camelize(:lower) },
      'credential_used' => sso_cookie_sign_credential_used,
      'expirationTime' => @session_object.ttl_in_time.iso8601(0)
    }
  end

  # Temporary solution for MHV having already coded this attribute differently than expected.
  def sso_cookie_sign_credential_used
    {
      'myhealthevet' => 'my_healthe_vet',
      'dslogon' => 'ds_logon',
      'idme' => 'id_me'
    }.fetch(@current_user.identity.sign_in.fetch(:service_name))
  end

  # Info for logging purposes related to SSO.
  def sso_logging_info
    {
      user_uuid: @current_user&.uuid,
      sso_cookie_contents: sso_cookie_content,
      request_host: request.host
    }
  end
end
# rubocop:enable Metrics/ModuleLength
