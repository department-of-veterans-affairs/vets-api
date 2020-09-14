# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'saml/settings_service'
require 'sentry_logging'
require 'aes_256_cbc_encryptor'

class BaseApplicationController < ActionController::API
  include SentryLogging
  include Pundit

  SKIP_SENTRY_EXCEPTION_TYPES = [
    Common::Exceptions::Unauthorized,
    Common::Exceptions::RoutingError,
    Common::Exceptions::Forbidden,
    Breakers::OutageException
  ].freeze

  prepend_before_action :block_unknown_hosts, :set_app_info_headers
  before_action :set_tags_and_extra_context

  def cors_preflight
    head(:ok)
  end

  def routing_error
    raise Common::Exceptions::RoutingError, params[:path]
  end

  private

  attr_reader :current_user

  def append_info_to_payload(payload)
    super
    payload[:session] = Session.obscure_token(session[:token]) if session && session[:token]
    payload[:user_uuid] = current_user.uuid if current_user.present?
  end

  # returns a Bad Request if the incoming host header is unsafe.
  def block_unknown_hosts
    return if controller_name == 'example'
    raise Common::Exceptions::NotASafeHostError, request.host unless Settings.virtual_hosts.include?(request.host)
  end

  def set_app_info_headers
    headers['X-Git-SHA'] = AppInfo::GIT_REVISION
    headers['X-GitHub-Repository'] = AppInfo::GITHUB_URL
  end

  def skip_sentry_exception_types
    SKIP_SENTRY_EXCEPTION_TYPES
  end

  rescue_from 'Exception' do |exception|
    va_exception =
      case exception
      when Pundit::NotAuthorizedError
        Common::Exceptions::Forbidden.new(detail: 'User does not have access to the requested resource')
      when ActionController::InvalidAuthenticityToken
        Common::Exceptions::Forbidden.new(detail: 'Invalid Authenticity Token')
      when Common::Exceptions::TokenValidationError
        Common::Exceptions::Unauthorized.new(detail: exception.detail)
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

    unless skip_sentry_exception_types.include?(exception.class)
      report_original_exception(exception)
      report_mapped_exception(exception, va_exception)
    end

    headers['WWW-Authenticate'] = 'Token realm="Application"' if va_exception.is_a?(Common::Exceptions::Unauthorized)
    render_errors(va_exception)
  end

  def render_errors(va_exception)
    render json: { errors: va_exception.errors }, status: va_exception.status_code
  end
end
