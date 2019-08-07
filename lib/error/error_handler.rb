# frozen_string_literal: true

module Error
  module ErrorHandler
    include SentryLogging

    def self.included(klass)
      klass.class_eval do
        rescue_from 'Exception' do |e|
          handle_the_error(e)
        end
      end
    end

    private

    SKIP_SENTRY_EXCEPTION_TYPES = [
      Common::Exceptions::Unauthorized,
      Common::Exceptions::RoutingError,
      Common::Exceptions::Forbidden,
      Breakers::OutageException
    ].freeze

    def skip_sentry_exception_types
      SKIP_SENTRY_EXCEPTION_TYPES
    end

    # TODO: Naming these handle_error and log_error cause conflicts with sessions controller
    #       and prompt further research into how we might re-negotiate our error handling as a whole
    def handle_the_error(exception)
      log_the_error(exception)
      va_exception = coerce_exception(exception)

      headers['WWW-Authenticate'] = 'Token realm="Application"' if va_exception.is_a?(Common::Exceptions::Unauthorized)

      render json: { errors: va_exception.errors }, status: va_exception.status_code
    end

    def log_the_error(exception)
      # report the original 'cause' of the exception when present
      if skip_sentry_exception_types.include?(exception.class)
        Rails.logger.error "#{exception.message}.", backtrace: exception.backtrace
      else
        # SentryLogger.new(exception).log_message
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
      end

      va_exception = coerce_exception(exception)

      unless skip_sentry_exception_types.include?(exception.class)
        va_exception_info = { va_exception_errors: va_exception.errors.map(&:to_hash) }
        log_exception_to_sentry(exception, extra.merge(va_exception_info))
      end
    end

    def coerce_exception(exception)
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
    end
  end
end
