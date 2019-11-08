# frozen_string_literal: true

module Common
  module Client
    module Errors
      ##
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

        # rubocop:disable Metrics/CyclomaticComplexity
        def transformed_error
          case error
          when Pundit::NotAuthorizedError
            Common::Exceptions::Forbidden.new(detail: 'User does not have access to the requested resource') # 403
          when ActionController::ParameterMissing
            Common::Exceptions::ParameterMissing.new(error.param) # 400
          when ActionController::UnknownFormat
            Common::Exceptions::UnknownFormat.new
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
        # rubocop:enable Metrics/CyclomaticComplexity
      end
    end
  end
end
