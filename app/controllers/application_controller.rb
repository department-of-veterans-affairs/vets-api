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
    Breakers::OutageException,
    Common::Exceptions::SentryIgnoredGatewayTimeout
  ].freeze

  before_action :authenticate
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
        if current_user.present?
          extra[:icn] = current_user.icn
          extra[:mhv_correlation_id] = current_user.mhv_correlation_id
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
    authenticate_with_http_token do |token, _options|
      @session = Session.find(token)
      return false if @session.nil?
      @current_user = User.find(@session.uuid)
      extend_session!
      return true if @current_user.present?
    end
  end

  # https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/SSO/CookieSpecs-20180906.docx
  def set_sso_cookie!
    return unless Settings.sso.cookie_enabled && @session.present?
    encryptor = SSOEncryptor
    contents = ActiveSupport::JSON.encode(@session.cookie_data)
    encrypted_value = encryptor.encrypt(contents)
    cookies[Settings.sso.cookie_name] = {
      value: encrypted_value,
      expires: nil, # NOTE: we track expiration as an attribute in "value." nil here means kill cookie on browser close.
      secure: Rails.env.production?,
      httponly: true,
      domain: cookie_domain
    }
  end

  def cookie_domain
    Rails.env.production? ? '.va.gov' : 'localhost'
  end

  def extend_session!
    session.expire(Session.redis_namespace_ttl)
    current_user&.identity&.expire(UserIdentity.redis_namespace_ttl)
    current_user&.expire(User.redis_namespace_ttl)
    set_sso_cookie!
  end

  def destroy_sso_cookie!
    cookies.delete(Settings.sso.cookie_name, domain: cookie_domain, secure: Rails.env.production?)
  end

  attr_reader :current_user, :session

  def render_unauthorized
    raise Common::Exceptions::Unauthorized
  end

  def saml_settings(options = {})
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
end
