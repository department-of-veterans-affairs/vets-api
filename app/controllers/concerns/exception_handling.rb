# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'

module ExceptionHandling
  extend ActiveSupport::Concern

  # In addition to Common::Exceptions::BackendServiceException that have sentry_type :none the following exceptions
  # will also be skipped.
  SKIP_SENTRY_EXCEPTION_TYPES = [
    Breakers::OutageException
  ].freeze

  private

  def skip_sentry_exception_types
    SKIP_SENTRY_EXCEPTION_TYPES
  end

  def skip_sentry_exception?(exception)
    return true if exception.class.in?(skip_sentry_exception_types)

    exception.respond_to?(:sentry_type) && !exception.log_to_sentry?
  end

  # rubocop:disable Metrics/BlockLength
  included do
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

      unless skip_sentry_exception?(exception)
        report_original_exception(exception)
        report_mapped_exception(exception, va_exception)
      end

      headers['WWW-Authenticate'] = 'Token realm="Application"' if va_exception.is_a?(Common::Exceptions::Unauthorized)
      render_errors(va_exception)
    end
  end
  # rubocop:enable Metrics/BlockLength

  def render_errors(va_exception)
    render json: { errors: va_exception.errors }, status: va_exception.status_code
  end

  def report_original_exception(exception)
    # report the original 'cause' of the exception when present
    if skip_sentry_exception?(exception)
      Rails.logger.error "#{exception.message}.", backtrace: exception.backtrace
    elsif exception.is_a?(Common::Exceptions::BackendServiceException) && exception.generic_error?
      # Warn about VA900 needing to be added to exception.en.yml
      log_message_to_sentry(exception.va900_warning, :warn, i18n_exception_hint: exception.va900_hint)
    end
  end

  def report_mapped_exception(exception, va_exception)
    extra = exception.respond_to?(:errors) ? { errors: exception.errors.map(&:to_hash) } : {}
    # Add additional user specific context to the logs
    if exception.is_a?(Common::Exceptions::BackendServiceException) && current_user.present?
      extra[:icn] = current_user.icn
      extra[:mhv_correlation_id] = current_user.mhv_correlation_id
    end
    va_exception_info = { va_exception_errors: va_exception.errors.map(&:to_hash) }
    log_exception_to_sentry(exception, extra.merge(va_exception_info))
  end
end
