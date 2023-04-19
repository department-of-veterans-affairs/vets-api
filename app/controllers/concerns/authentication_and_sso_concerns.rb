# frozen_string_literal: true

# This module only gets mixed in to one place, but is that cleanest way to organize everything in one place related
# to this responsibility alone.
module AuthenticationAndSSOConcerns
  extend ActiveSupport::Concern
  include ActionController::Cookies
  include SignIn::Authentication

  included do
    before_action :authenticate
    before_action :set_session_expiration_header
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

  def load_user
    if cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME]
      super
    else
      @session_object = Session.find(session[:token])
      @current_user = User.find(@session_object.uuid) if @session_object&.uuid
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
  def set_api_cookie!
    return unless @session_object

    session.delete :value
    @session_object.to_hash.each { |k, v| session[k] = v }
  end

  def set_session_expiration_header
    headers['X-Session-Expiration'] = @session_object.ttl_in_time.httpdate if @session_object.present?
  end

  # Info for logging purposes related to SSO.
  def sso_logging_info
    { user_uuid: @current_user&.uuid,
      sso_cookie_contents: sso_cookie_content,
      request_host: request.host }
  end

  private

  def sso_cookie_content
    return nil if @current_user.blank?

    { 'patientIcn' => @current_user.icn,
      'signIn' => @current_user.identity.sign_in.deep_transform_keys { |key| key.to_s.camelize(:lower) },
      'credential_used' => @current_user.identity.sign_in[:service_name],
      'session_uuid' => sign_in_service_session ? @access_token.session_handle : @session_object.uuid,
      'expirationTime' => sign_in_service_session ? sign_in_service_exp_time : @session_object.ttl_in_time.iso8601(0) }
  end

  def sign_in_service_exp_time
    sign_in_service_session.refresh_expiration.iso8601(0)
  end

  def sign_in_service_session
    return unless @access_token

    @sign_in_service_session ||= SignIn::OAuthSession.find_by(handle: @access_token.session_handle)
  end
end
