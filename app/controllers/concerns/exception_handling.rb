# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'
require 'json_schema/json_api_missing_attribute'
require 'datadog'
require 'vets/shared_logging'

module ExceptionHandling
  extend ActiveSupport::Concern
  include Vets::SharedLogging

  # In addition to Common::Exceptions::BackendServiceException that have sentry_type :none the following exceptions
  # will also be skipped.
  SKIP_SENTRY_EXCEPTION_TYPES = [
    Breakers::OutageException,
    JsonSchema::JsonApiMissingAttribute,
    Pundit::NotAuthorizedError
  ].freeze

  private

  def skip_sentry_exception_types
    SKIP_SENTRY_EXCEPTION_TYPES
  end

  def skip_sentry_exception?(exception)
    return true if exception.class.in?(skip_sentry_exception_types)

    exception.respond_to?(:sentry_type) && !exception.log_to_sentry?
  end

  included do
    rescue_from 'Exception' do |exception|
      va_exception =
        case exception
        when Pundit::NotAuthorizedError
          Common::Exceptions::Forbidden.new(detail: 'User does not have access to the requested resource')
        when ActionController::InvalidAuthenticityToken
          Common::Exceptions::Forbidden.new(detail: 'Invalid Authenticity Token')
        when Common::Exceptions::TokenValidationError,
            Common::Exceptions::BaseError, JsonSchema::JsonApiMissingAttribute,
          Common::Exceptions::ServiceUnavailable, Common::Exceptions::BadGateway
          exception
        when ActionController::ParameterMissing
          Common::Exceptions::ParameterMissing.new(exception.param)
        when Breakers::OutageException
          Common::Exceptions::ServiceOutage.new(exception.outage)
        when Common::Client::Errors::ClientError
          # SSLError, ConnectionFailed, SerializationError, etc
          Common::Exceptions::ServiceOutage.new(nil, detail: 'Backend Service Outage')
        else
          Common::Exceptions::InternalServerError.new(exception)
        end

      unless skip_sentry_exception?(exception)
        report_original_exception(exception)
        report_mapped_exception(exception, va_exception)
      end

      headers['WWW-Authenticate'] = 'Token realm="Application"' if va_exception.is_a?(Common::Exceptions::Unauthorized)
      render_errors(va_exception)
    end
  end
  def render_errors(va_exception)
    case va_exception
    when JsonSchema::JsonApiMissingAttribute
      render json: va_exception.to_json_api, status: va_exception.code
    else
      render json: { errors: va_exception.errors }, status: va_exception.status_code
    end
  end

  def report_original_exception(exception)
    # report the original 'cause' of the exception when present
    if skip_sentry_exception?(exception)
      Rails.logger.error "#{exception.message}.", backtrace: exception.backtrace
    elsif exception.is_a?(Common::Exceptions::BackendServiceException) && exception.generic_error?
      # Warn about VA900 needing to be added to exception.en.yml
      log_message_to_sentry(exception.va900_warning, :warn, i18n_exception_hint: exception.va900_hint)
      log_message_to_rails(exception.va900_warning, :warn, i18n_exception_hint: exception.va900_hint)
    end
  end

  def report_mapped_exception(exception, va_exception)
    extra = exception.respond_to?(:errors) ? { errors: exception.errors.map(&:to_h) } : {}
    # Add additional user specific context to the logs
    if exception.is_a?(Common::Exceptions::BackendServiceException) && current_user.present?
      extra[:icn] = current_user.icn
      extra[:mhv_credential_uuid] = current_user.mhv_credential_uuid
    end
    va_exception_info = { va_exception_errors: va_exception.errors.map(&:to_hash) }
    log_exception_to_sentry(exception, extra.merge(va_exception_info))
    log_exception_to_rails(exception)

    # Because we are handling exceptions here and not re-raising, we need to set the error on the
    # Datadog span for it to be reported correctly. We also need to set it on the top-level
    # (Rack) span for errors to show up in the Datadog Error Tracking console.
    # Datadog does not support setting rich structured context on spans so we are ignoring
    # the extra va_exception and other context for now. We can set tags in Datadog as they are used
    # in Sentry, but tags are not suitable for complex objects.
    Datadog::Tracing.active_span&.set_error(exception)
    request.env[Datadog::Tracing::Contrib::Rack::Ext::RACK_ENV_REQUEST_SPAN]&.set_error(exception)
  end
end
