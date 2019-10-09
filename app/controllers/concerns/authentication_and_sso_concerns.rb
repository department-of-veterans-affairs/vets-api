# frozen_string_literal: true

# This module only gets mixed in to one place, but is that cleanest way to organize everything in one place related
# to this responsibility alone.
module AuthenticationAndSSOConcerns
  extend ActiveSupport::Concern
  include ActionController::HttpAuthentication::Token::ControllerMethods
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
    @session_object = Session.find(session[:token])

    if @session_object.nil?
      Rails.logger.info('SSO: INVALID SESSION', sso_logging_info)
      reset_session
      return false
    end

    @current_user = User.find(@session_object.uuid)

    if should_signout_sso?
      Rails.logger.info('SSO: MHV INITIATED SIGNOUT', sso_logging_info)
      reset_session
    else
      Rails.logger.info('SSO: EXTENDING SESSION', sso_logging_info)
      extend_session!
    end

    @current_user.present?
  end

  # Destroys the users session in 1) Redis, 1) the MHV SSO Cookie, 3) and the Session Cookie
  def reset_session
    Rails.logger.info('SSO: ApplicationController#reset_session', sso_logging_info)

    cookies.delete(Settings.sso.cookie_name, domain: Settings.sso.cookie_domain)
    @session_object&.destroy
    @current_user&.destroy
    @session_object = nil
    @current_user = nil
    super
  end

  # Determines whether user signed out of MHV's website
  def should_signout_sso?
    Rails.logger.info('SSO: ApplicationController#should_signout_sso?', sso_logging_info)
    return false unless Settings.sso.cookie_enabled
    return false unless Settings.sso.cookie_signout_enabled

    cookies[Settings.sso.cookie_name].blank? && request.host.match(Settings.sso.cookie_domain)
  end

  # Extends the users session, including the MHV SSO Cookie
  def extend_session!
    Rails.logger.info('SSO: ApplicationController#extend_session!', sso_logging_info)

    @session_object.expire(Session.redis_namespace_ttl)
    @current_user&.identity&.expire(UserIdentity.redis_namespace_ttl)
    @current_user&.expire(User.redis_namespace_ttl)
    set_sso_cookie!
  end

  # Sets a cookie "api_session" with all of the key/value pairs from session object.
  def set_api_cookie!
    return unless @session_object

    @session_object.to_hash.each { |k, v| session[k] = v }
  end

  # Sets a cookie used by MHV for SSO
  def set_sso_cookie!
    Rails.logger.info('SSO: ApplicationController#set_sso_cookie!', sso_logging_info)

    return unless Settings.sso.cookie_enabled && @session_object.present?

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
      'idme' => 'id_me',
      'ssoe' => 'ssoe'
    }.fetch(@current_user.identity.sign_in.fetch(:service_name))
  end

  # Info for logging purposes related to SSO.
  def sso_logging_info
    {
      sso_cookies_enabled: Settings.sso.cookie_enabled,
      sso_cookies_signout_enabled: Settings.sso.cookie_signout_enabled,
      sso_cookie_name: Settings.sso.cookie_name,
      sso_cookie_contents: sso_cookie_content,
      request_host: request.host
    }
  end
end
