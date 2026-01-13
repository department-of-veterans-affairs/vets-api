# frozen_string_literal: true

# ErrorHandler Concern
#
# This concern provides a standardized way to handle and log common controller errors.
# It wraps controller actions in consistent error handling and provides structured
# logging with automatic error response formatting.
#
# ## Usage:
#   include ErrorHandler
#
#   def some_action
#     handle_service_errors('operation description') do
#       # Your controller logic here
#       # Will automatically catch and handle BackendServiceException and generic errors
#     end
#   end
#
# ## Error Types Handled:
# - Common::Exceptions::BackendServiceException → 503 Service Unavailable
# - Generic exceptions → 500 Internal Server Error
#
# ## Logging:
# All errors are logged with structured data including:
# - user_uuid (if current_user available)
# - error message and backtrace
# - operation context
#
module ErrorHandler
  extend ActiveSupport::Concern

  # Handle common service errors with consistent logging and responses
  #
  # @param operation_context [String] Description of the operation for logging
  # @param include_backtrace [Boolean] Whether to include backtrace in unexpected error logs
  # @yield Block containing the controller logic to execute
  def handle_service_errors(operation_context, include_backtrace: true)
    yield
  rescue Common::Exceptions::BackendServiceException => e
    log_service_error(operation_context, e)
    render_service_unavailable_error
  rescue Common::Exceptions::TooManyRequests => e
    log_rate_limit_error(operation_context, e)
    render_rate_limit_error
  rescue => e
    log_unexpected_error(operation_context, e, include_backtrace:)
    render_internal_server_error
  end

  # Log successful operations with structured data
  #
  # @param operation_context [String] Description of the operation
  # @param additional_data [Hash] Additional structured data to include in log
  def log_operation_success(operation_context, **additional_data)
    log_data = base_log_data.merge(additional_data)

    Rails.logger.info(operation_context, log_data)
  end

  private

  # Log backend service errors with structured data
  def log_service_error(operation_context, error)
    log_data = base_log_data.merge(
      error: error.message,
      error_class: error.class.name
    )

    Rails.logger.error("#{operation_context} - service error", log_data)
  end

  # Log rate limit errors with structured data
  def log_rate_limit_error(operation_context, error)
    log_data = base_log_data.merge(
      error: error.message,
      error_class: error.class.name
    )

    Rails.logger.warn("#{operation_context} - rate limit exceeded", log_data)
  end

  # Log unexpected errors with structured data
  def log_unexpected_error(operation_context, error, include_backtrace: true)
    log_data = base_log_data.merge(
      error: error.message,
      error_class: error.class.name
    )

    log_data[:backtrace] = error.backtrace if include_backtrace

    Rails.logger.error("#{operation_context} - unexpected error", log_data)
  end

  # Render standard service unavailable error response
  def render_service_unavailable_error
    render json: {
      errors: [
        {
          title: 'Service Unavailable',
          detail: 'Service is temporarily unavailable. Please try again later.',
          code: 'SERVICE_UNAVAILABLE',
          status: '503'
        }
      ]
    }, status: :service_unavailable
  end

  # Render standard rate limit error response
  def render_rate_limit_error
    render json: {
      errors: [
        {
          title: 'Rate Limit Exceeded',
          detail: 'Request limit exceeded. Please try again later.',
          code: 'RATE_LIMIT_EXCEEDED',
          status: '429'
        }
      ]
    }, status: :too_many_requests
  end

  # Render standard internal server error response
  def render_internal_server_error
    render json: {
      errors: [
        {
          title: 'Internal Server Error',
          detail: 'An unexpected error occurred. Please try again later.',
          code: 'INTERNAL_SERVER_ERROR',
          status: '500'
        }
      ]
    }, status: :internal_server_error
  end

  # Base logging data that includes user information when available
  def base_log_data
    data = {}
    data[:user_uuid] = current_user.uuid if respond_to?(:current_user) && current_user&.uuid
    data
  end
end
