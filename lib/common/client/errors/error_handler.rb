# frozen_string_literal: true

module Common
  module Client
    module Errors
      # This class is responsible for providing a public interface to perform common error handling tasks.
      # We want to catch any error and coerce the message and status code that is returned to the client.
      # This is because many of our backend services could return an error that is inaccurate or not quite exceptional.
      class ErrorHandler
        include SentryLogging

        attr_accessor :error, :va_exception

        def initialize(error)
          @error = error
          @va_exception = transformed_error
        end

        def log_error
          super(error)
        end

        def transformed_error
          # TODO: this is an example, the interface should be the same but the implementation can differ
          case error
          when Pundit::NotAuthorizedError
            Common::Exceptions::Forbidden.new(detail: 'User does not have access to the requested resource') # 403
          when ActionController::ParameterMissing
            Common::Exceptions::ParameterMissing.new(error.param) # 400
          when ActionController::UnknownFormat
            Common::Exceptions::UnknownFormat.new
            # 406
          when Common::Exceptions::BaseError # inferred adheranced to interface/status/response schema
            error
          when Breakers::OutageException
            Common::Exceptions::ServiceOutage.new(error.outage) # 503
          when Common::Client::Errors::ClientError
            Common::Exceptions::ServiceOutage.new(nil, detail: 'Backend Service Outage') # 503 but we don't know enough?
          else
            Common::Exceptions::InternalServerError.new(error)
          end
        end
      end
    end
  end
end
#
# rescue_from Encoding::CompatibilityError do |exception|
#   log_exception(exception)
#   render "errors/encoding", layout: "errors", status: 500
# end
#
# rescue_from ActiveRecord::RecordNotFound do |exception|
#   log_exception(exception)
#   render_404
# end
#
# rescue_from(ActionController::UnknownFormat) do
#   render_404
# end
#
# rescue_from Gitlab::Access::AccessDeniedError do |exception|
#   render_403
# end
#
# rescue_from Gitlab::Auth::TooManyIps do |e|
#   head :forbidden, retry_after: Gitlab::Auth::UniqueIpsLimiter.config.unique_ips_limit_time_window
# end
#
# rescue_from GRPC::Unavailable, Gitlab::Git::CommandError do |exception|
#   log_exception(exception)
#
#   headers['Retry-After'] = exception.retry_after if exception.respond_to?(:retry_after)
#
#   render_503
# end
