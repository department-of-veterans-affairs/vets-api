# frozen_string_literal: true

# EmailVerificationErrorHandler Concern
#
# This concern provides specialized error handling for email verification operations.
# It handles the specific error scenarios that can occur during email verification
# workflow and provides consistent logging and responses.
#
# ## Usage:
#   include EmailVerificationErrorHandler
#
#   def create
#     handle_verification_errors('send verification email') do
#       # Email verification logic here
#     end
#   end
#
# ## Email Verification Specific Error Types:
# - Common::Exceptions::BackendServiceException → 503 Service Unavailable
# - Common::Exceptions::TooManyRequests → 429 Too Many Requests
# - Generic exceptions → 500 Internal Server Error
#
# ## Logging:
# All errors are logged with email verification context including:
# - user_uuid (non-PII identifier)
# - verification operation context
# - rate limiting information when applicable
# - verification status (needed/not needed)
#
# Note: Email addresses are NOT logged to protect user privacy.
#
module EmailVerificationErrorHandler
  extend ActiveSupport::Concern

  # Handle errors specific to email verification operations
  #
  # @param verification_operation [String] Description of the verification operation
  # @yield Block containing the email verification logic to execute
  def handle_verification_errors(verification_operation)
    yield
  rescue Common::Exceptions::BackendServiceException => e
    log_verification_service_error(verification_operation, e)
    render_email_service_unavailable_error
  rescue Common::Exceptions::TooManyRequests => e
    log_verification_rate_limit_error(verification_operation, e)
    render_verification_rate_limit_error
  rescue => e
    log_unexpected_verification_error(verification_operation, e)
    render_verification_internal_error
  end

  # Log successful email verification operations
  #
  # @param verification_operation [String] Description of the operation
  # @param verification_data [Hash] Email verification specific data
  def log_verification_success(verification_operation, **verification_data)
    log_data = email_verification_log_data.merge(verification_data)

    Rails.logger.info("Email verification: #{verification_operation}", log_data)
  end

  private

  def log_verification_service_error(operation, error)
    log_data = email_verification_log_data.merge(
      error: error.message,
      error_class: error.class.name
    )

    Rails.logger.error("Email verification service error: #{operation}", log_data)
  end

  def log_verification_rate_limit_error(operation, error)
    log_data = email_verification_log_data.merge(
      error: error.message,
      error_class: error.class.name
    )

    # Only add rate limit info if the method exists and doesn't raise an error
    begin
      if respond_to?(:get_email_verification_rate_limit_info)
        log_data[:rate_limit_info] =
          get_email_verification_rate_limit_info
      end
    rescue => e
      log_data[:rate_limit_info_error] = e.message
    end

    Rails.logger.warn("Email verification rate limit exceeded: #{operation}", log_data)
  end

  def log_unexpected_verification_error(operation, error)
    log_data = email_verification_log_data.merge(
      error: error.message,
      error_class: error.class.name
    )

    Rails.logger.error("Email verification unexpected error: #{operation}", log_data)
  end

  def render_email_service_unavailable_error
    render json: {
      errors: [
        {
          title: 'Email Verification Service Unavailable',
          detail: 'The email verification service is temporarily unavailable. Please try again later.',
          code: 'EMAIL_VERIFICATION_SERVICE_UNAVAILABLE',
          status: '503'
        }
      ]
    }, status: :service_unavailable
  end

  # Render email verification rate limit error with retry information
  def render_verification_rate_limit_error(exception = nil)
    retry_after = if exception.respond_to?(:retry_after) && exception.retry_after
                    exception.retry_after
                  else
                    300 # Default 5 minutes
                  end

    response.headers['Retry-After'] = retry_after.to_s

    render json: {
      errors: [
        {
          title: 'Email Verification Rate Limit Exceeded',
          detail: 'Too many verification emails sent. Please wait before requesting another verification email.',
          code: 'EMAIL_VERIFICATION_RATE_LIMIT_EXCEEDED',
          status: '429',
          meta: {
            retry_after_seconds: retry_after
          }
        }
      ]
    }, status: :too_many_requests
  end

  def render_verification_internal_error
    render json: {
      errors: [
        {
          title: 'Email Verification Error',
          detail: 'An unexpected error occurred during email verification. Please try again later.',
          code: 'EMAIL_VERIFICATION_INTERNAL_ERROR',
          status: '500'
        }
      ]
    }, status: :internal_server_error
  end

  def email_verification_log_data
    data = {}

    if respond_to?(:current_user) && current_user
      data[:user_uuid] = current_user.uuid
      data[:verification_needed] = needs_verification? if respond_to?(:needs_verification?)
    end

    data
  end
end
