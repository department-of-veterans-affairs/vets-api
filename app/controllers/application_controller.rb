# frozen_string_literal: true
require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'saml/settings_service'
require 'sentry_logging'

class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  include SentryLogging

  SKIP_SENTRY_EXCEPTION_TYPES = [
    Common::Exceptions::Unauthorized,
    Common::Exceptions::RoutingError,
    Common::Exceptions::Forbidden,
    Breakers::OutageException
  ].freeze

  before_action :authenticate
  before_action :set_app_info_headers
  before_action :set_uuid_tags
  skip_before_action :authenticate, only: [:cors_preflight, :routing_error]

  def cors_preflight
    head(:ok)
  end

  def clear_saved_form(form_id)
    if @current_user
      InProgressForm.form_for_user(form_id, @current_user)&.destroy
    end
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

  rescue_from 'Exception' do |exception|
    # report the original 'cause' of the exception when present
    if SKIP_SENTRY_EXCEPTION_TYPES.include?(exception.class) == false
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
    else
      Rails.logger.error "#{exception.message}."
      Rails.logger.error exception.backtrace.join("\n") unless exception.backtrace.nil?
    end

    va_exception =
      case exception
      when ActionController::ParameterMissing
        Common::Exceptions::ParameterMissing.new(exception.param)
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

    if va_exception.is_a?(Common::Exceptions::Unauthorized)
      headers['WWW-Authenticate'] = 'Token realm="Application"'
    end
    render json: { errors: va_exception.errors }, status: va_exception.status_code
  end

  def set_uuid_tags
    Thread.current['request_id'] = request.uuid
    Raven.extra_context(request_uuid: request.uuid)
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
      # TODO: ensure that this prevents against timing attack vectors
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(token),
        ::Digest::SHA256.hexdigest(@session.token)
      )
      @current_user = User.find(@session.uuid)
      extend_session
    end
  end

  def extend_session
    @session.expire(Session.redis_namespace_ttl)
    @current_user&.expire(User.redis_namespace_ttl)
  end

  attr_reader :current_user

  def render_unauthorized
    raise Common::Exceptions::Unauthorized
  end

  def saml_settings(options = {})
    # Make sure we're not changing the settings globally
    base_settings = SAML::SettingsService.saml_settings.dup

    options.each do |option, value|
      next if value.nil?
      base_settings.send("#{option}=", value)
    end

    base_settings
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
