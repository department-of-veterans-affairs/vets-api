# frozen_string_literal: true

module EmailVerificationErrorHandler
  extend ActiveSupport::Concern

  DEFAULT_RETRY_AFTER_SECONDS = 300 # 5 minutes

  def handle_verification_errors(verification_operation)
    yield
  rescue Common::Exceptions::BackendServiceException => e
    log_verification_service_error(verification_operation, e)
    render_email_service_unavailable_error
  rescue Common::Exceptions::TooManyRequests => e
    log_verification_rate_limit_error(verification_operation, e)
    render_verification_rate_limit_error(e)
  rescue => e
    log_unexpected_verification_error(verification_operation, e)
    render_verification_internal_error
  end

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

  def render_verification_rate_limit_error(exception = nil)
    retry_after = if exception.respond_to?(:retry_after) && exception.retry_after
                    exception.retry_after
                  else
                    DEFAULT_RETRY_AFTER_SECONDS
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
