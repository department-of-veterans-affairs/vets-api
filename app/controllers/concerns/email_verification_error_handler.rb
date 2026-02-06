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
    render_verification_rate_limit_error
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
      log_data[:rate_limit_info] = get_email_verification_rate_limit_info
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
      errors: [{
        title: 'Email Verification Service Unavailable',
        detail: 'The email verification service is temporarily unavailable. Please try again later.',
        code: 'EMAIL_VERIFICATION_SERVICE_UNAVAILABLE',
        status: '503'
      }]
    }, status: :service_unavailable
  end

  def render_verification_rate_limit_error
    retry_after = response.headers['Retry-After'].to_i

    if retry_after <= 0
      retry_after = begin
        time_until_next_verification_allowed.to_i
      rescue
        0
      end
    end

    retry_after = DEFAULT_RETRY_AFTER_SECONDS if retry_after <= 0
    response.headers['Retry-After'] = retry_after.to_s

    detail_message = build_verification_rate_limit_message

    render json: {
      errors: [{
        title: 'Email Verification Rate Limit Exceeded',
        detail: detail_message,
        code: 'EMAIL_VERIFICATION_RATE_LIMIT_EXCEEDED',
        status: '429',
        meta: { retry_after_seconds: retry_after }
      }]
    }, status: :too_many_requests
  end

  def render_verification_internal_error
    render json: {
      errors: [{
        title: 'Email Verification Error',
        detail: 'An unexpected error occurred during email verification. Please try again later.',
        code: 'EMAIL_VERIFICATION_INTERNAL_ERROR',
        status: '500'
      }]
    }, status: :internal_server_error
  end

  def email_verification_log_data
    return {} unless current_user

    {
      user_uuid: current_user.uuid,
      verification_needed: needs_verification?
    }
  end
end
