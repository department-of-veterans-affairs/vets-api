# frozen_string_literal: true

module ExceptionHandling
  extend ActiveSupport::Concern

  SKIP_SENTRY_EXCEPTION_TYPES = [
    Common::Exceptions::Unauthorized,
    Common::Exceptions::RoutingError,
    Common::Exceptions::Forbidden,
    Breakers::OutageException
  ].freeze

  private

  def skip_sentry_exception_types
    SKIP_SENTRY_EXCEPTION_TYPES
  end

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
    
      unless skip_sentry_exception_types.include?(exception.class)
        report_original_exception(exception)
        report_mapped_exception(exception, va_exception)
      end
    
      headers['WWW-Authenticate'] = 'Token realm="Application"' if va_exception.is_a?(Common::Exceptions::Unauthorized)
      render_errors(va_exception)
    end
  end

  def render_errors(va_exception)
    render json: { errors: va_exception.errors }, status: va_exception.status_code
  end
end
