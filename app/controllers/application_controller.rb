# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'saml/settings_service'
require 'sentry_logging'
require 'aes_256_cbc_encryptor'

class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  include ActionController::Cookies
  include SentryLogging
  include Pundit

  SKIP_SENTRY_EXCEPTION_TYPES = [
    Common::Exceptions::Unauthorized,
    Common::Exceptions::RoutingError,
    Common::Exceptions::Forbidden,
    Breakers::OutageException
  ].freeze

  before_action :block_unknown_hosts
  before_action :authenticate

  # Ensures that we maintain sessions for currently signed-in users
  # (that have been authenticated with the HTTP header)
  # after we start using cookies instead of the header.
  before_action :set_api_cookie!, unless: -> { Settings.session_cookie.enabled }

  before_action :set_app_info_headers
  before_action :set_tags_and_extra_context
  skip_before_action :authenticate, only: %i[cors_preflight routing_error]

  def tag_rainbows
    Sentry::TagRainbows.tag
  end

  def cors_preflight
    head(:ok)
  end

  def clear_saved_form(form_id)
    InProgressForm.form_for_user(form_id, @current_user)&.destroy if @current_user
  end

  def routing_error
    raise Common::Exceptions::RoutingError, params[:path]
  end

  # I'm commenting this out for now, we can put it back in if we encounter it
  # def action_missing(m, *_args)
  #   Rails.logger.error(m)
  #   raise Common::Exceptions::RoutingError
  # end

  private

  attr_reader :current_user

  # returns a Bad Request if the incoming host header is unsafe.
  def block_unknown_hosts
    return if controller_name == 'example'
    raise Common::Exceptions::NotASafeHostError, request.host unless Settings.virtual_hosts.include?(request.host)
  end

  def skip_sentry_exception_types
    SKIP_SENTRY_EXCEPTION_TYPES
  end

  # rubocop:disable Metrics/BlockLength
  rescue_from 'Exception' do |exception|
    # report the original 'cause' of the exception when present
    if skip_sentry_exception_types.include?(exception.class)
      Rails.logger.error "#{exception.message}."
      Rails.logger.error exception.backtrace.join("\n") unless exception.backtrace.nil?
    else
      extra = exception.respond_to?(:errors) ? { errors: exception.errors.map(&:to_hash) } : {}
      if exception.is_a?(Common::Exceptions::BackendServiceException)
        # Add additional user specific context to the logs
        if @current_user.present?
          extra[:icn] = @current_user.icn
          extra[:mhv_correlation_id] = @current_user.mhv_correlation_id
        end
        # Warn about VA900 needing to be added to exception.en.yml
        if exception.generic_error?
          log_message_to_sentry(exception.va900_warning, :warn, i18n_exception_hint: exception.va900_hint)
        end
      end
      log_exception_to_sentry(exception, extra)
    end

    va_exception =
      case exception
      when Pundit::NotAuthorizedError
        Common::Exceptions::Forbidden.new(detail: 'User does not have access to the requested resource')
      when ActionController::ParameterMissing
        Common::Exceptions::ParameterMissing.new(exception.param)
      when ActionController::UnknownFormat
        Common::Exceptions::UnknownFormat.new
      when Common::Exceptions::BaseError
        exception
      when Breakers::OutageException
        Common::Exceptions::ServiceOutage.new(exception.outage)
      when Common::Client::Errors::ClientError
        # SSLError, ConnectionFailed, SerializationError, etc
        Common::Exceptions::ServiceOutage.new(nil, detail: 'Backend Service Outage')
      else
        Common::Exceptions::InternalServerError.new(exception)
      end

    headers['WWW-Authenticate'] = 'Token realm="Application"' if va_exception.is_a?(Common::Exceptions::Unauthorized)
    render json: { errors: va_exception.errors }, status: va_exception.status_code
  end
  # rubocop:enable Metrics/BlockLength

  def set_tags_and_extra_context
    Thread.current['request_id'] = request.uuid
    Raven.extra_context(request_uuid: request.uuid)
    Raven.user_context(user_context) if @current_user
    Raven.tags_context(tags_context)
  end

  def user_context
    {
      uuid: @current_user&.uuid,
      authn_context: @current_user&.authn_context,
      loa: @current_user&.loa,
      mhv_icn: @current_user&.mhv_icn
    }
  end

  def tags_context
    {
      controller_name: controller_name,
      sign_in_method: @current_user.present? ? @current_user.authn_context || 'idme' : 'not-signed-in'
    }
  end

  def set_app_info_headers
    headers['X-GitHub-Repository'] = 'https://github.com/department-of-veterans-affairs/vets-api'
    headers['X-Git-SHA'] = AppInfo::GIT_REVISION
  end

  def authenticate
    authenticate_token || render_unauthorized
  end

  def authenticate_token
    return validate_session(session[:token]) if Settings.session_cookie.enabled
    authenticate_with_http_token do |token, _options|
      validate_session(token)
    end
  end

  def validate_session(token)
    @session_object = Session.find(token)

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

  def extend_session!
    Rails.logger.info('SSO: ApplicationController#extend_session!', sso_logging_info)

    @session_object.expire(Session.redis_namespace_ttl)
    @current_user&.identity&.expire(UserIdentity.redis_namespace_ttl)
    @current_user&.expire(User.redis_namespace_ttl)
    set_sso_cookie!
  end

  def reset_session
    Rails.logger.info('SSO: ApplicationController#reset_session', sso_logging_info)

    cookies.delete(Settings.sso.cookie_name, domain: Settings.sso.cookie_domain)
    @session_object&.destroy
    @current_user&.destroy
    @session_object = nil
    @current_user = nil
    super
  end

  # Sets a cookie "api_session" with all of the key/value pairs from session object.
  def set_api_cookie!
    return unless @session_object
    @session_object.to_hash.each { |k, v| session[k] = v }
  end

  # https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/SSO/CookieSpecs-20180906.docx
  def set_sso_cookie!
    Rails.logger.info('SSO: ApplicationController#set_sso_cookie!', sso_logging_info)

    return unless Settings.sso.cookie_enabled && @session_object.present?
    encryptor = SSOEncryptor
    contents = ActiveSupport::JSON.encode(@session_object.cookie_data(@current_user))
    encrypted_value = encryptor.encrypt(contents)
    cookies[Settings.sso.cookie_name] = {
      value: encrypted_value,
      expires: nil, # NOTE: we track expiration as an attribute in "value." nil here means kill cookie on browser close.
      secure: Settings.sso.cookie_secure,
      httponly: true,
      domain: Settings.sso.cookie_domain
    }
  end

  def should_signout_sso?
    Rails.logger.info('SSO: ApplicationController#should_signout_sso?', sso_logging_info)
    return false unless Settings.sso.cookie_enabled
    return false unless Settings.sso.cookie_signout_enabled
    cookies[Settings.sso.cookie_name].blank? && request.host.match(Settings.sso.cookie_domain)
  end

  def render_unauthorized
    raise Common::Exceptions::Unauthorized
  end

  def saml_settings(options = {})
    callback_url = URI.parse(Settings.saml.callback_url)
    callback_url.host = request.host
    options.reverse_merge!(assertion_consumer_service_url: callback_url.to_s)
    SAML::SettingsService.saml_settings(options)
  end

  def pagination_params
    {
      page: params[:page],
      per_page: params[:per_page]
    }
  end

  def render_job_id(jid)
    render json: { job_id: jid }, status: 202
  end

  def sso_logging_info
    {
      sso_cookies_enabled: Settings.sso.cookie_enabled,
      sso_cookies_signout_enabled: Settings.sso.cookie_signout_enabled,
      sso_cookie_name: Settings.sso.cookie_name,
      sso_cookie_contents: @session_object&.cookie_data(@current_user),
      request_host: request.host
    }
  end
end
