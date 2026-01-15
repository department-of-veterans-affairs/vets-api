# frozen_string_literal: true

# EmailVerificationRateLimited concern provides Redis-based rate limiting
# specifically for email verification operations.
#
# This concern is tailored specifically for email verification with:
# - Pre-configured limits: 1 email per 5 minutes, 5 emails per 24 hours
# - Email verification-specific error messages and logging
# - Automatic rate limit reset upon successful verification
#
# Usage:
#   class EmailVerificationController < ApplicationController
#     include EmailVerificationRateLimited
#
#     def create
#       enforce_email_verification_rate_limit!
#       # ... send email logic
#       increment_email_verification_rate_limit!
#     end
#   end
#
module EmailVerificationRateLimited
  extend ActiveSupport::Concern

  # Email verification rate limiting configuration
  VERIFICATION_EMAIL_LIMITS = {
    per_period: 1,
    period: 5.minutes,
    daily_limit: 5,
    daily_period: 24.hours,
    redis_namespace: 'email_verification_rate_limit'
  }.freeze

  # Enforce email verification rate limiting
  # Raises TooManyRequests exception if rate limit exceeded
  def enforce_email_verification_rate_limit!
    return unless email_verification_rate_limit_exceeded?

    rate_limit_info = get_email_verification_rate_limit_info
    log_email_verification_rate_limit_denial(rate_limit_info)

    retry_after = time_until_next_verification_allowed
    exception = Common::Exceptions::TooManyRequests.new(
      detail: build_verification_rate_limit_message
    )

    # Add retry_after if the exception supports it
    exception.define_singleton_method(:retry_after) { retry_after } if exception.respond_to?(:define_singleton_method)

    raise exception
  end

  # Check if email verification rate limit is exceeded
  #
  # @return [Boolean] true if rate limit exceeded
  def email_verification_rate_limit_exceeded?
    verification_period_count >= VERIFICATION_EMAIL_LIMITS[:per_period] ||
      verification_daily_count >= VERIFICATION_EMAIL_LIMITS[:daily_limit]
  end

  # Increment email verification rate limit counters
  def increment_email_verification_rate_limit!
    verification_redis.multi do |multi|
      multi.incr(verification_period_key)
      multi.expire(verification_period_key, VERIFICATION_EMAIL_LIMITS[:period].to_i)
    end

    verification_redis.multi do |multi|
      multi.incr(verification_daily_key)
      multi.expire(verification_daily_key, VERIFICATION_EMAIL_LIMITS[:daily_period].to_i)
    end

    # Clear cached counts
    clear_verification_rate_limit_cache
  end

  # Reset email verification rate limit counters (called on successful verification)
  def reset_email_verification_rate_limit!
    verification_redis.del(verification_period_key, verification_daily_key)
    clear_verification_rate_limit_cache
  end

  # Get current email verification rate limit information
  #
  # @return [Hash] Rate limit statistics
  def get_email_verification_rate_limit_info
    {
      period_count: verification_period_count,
      daily_count: verification_daily_count,
      max_per_period: VERIFICATION_EMAIL_LIMITS[:per_period],
      max_daily: VERIFICATION_EMAIL_LIMITS[:daily_limit],
      period_minutes: VERIFICATION_EMAIL_LIMITS[:period].to_i / 60,
      time_until_next_email: time_until_next_verification_allowed
    }
  end

  private

  # Get current period count for verification emails
  def verification_period_count
    @verification_period_count ||= verification_redis.get(verification_period_key).to_i
  end

  # Get current daily count for verification emails
  def verification_daily_count
    @verification_daily_count ||= verification_redis.get(verification_daily_key).to_i
  end

  # Clear cached rate limit counts
  def clear_verification_rate_limit_cache
    @verification_period_count = nil
    @verification_daily_count = nil
  end

  # Get seconds until next verification email is allowed
  def time_until_next_verification_allowed
    ttl_period = verification_redis.ttl(verification_period_key)
    ttl_daily = verification_redis.ttl(verification_daily_key)

    # Return the larger of the two TTLs
    [ttl_period, ttl_daily, 0].max
  end

  # Build email verification specific error message
  def build_verification_rate_limit_message
    seconds = time_until_next_verification_allowed
    duration = format_verification_time_duration(seconds)

    'You have exceeded the maximum number of verification emails allowed. ' \
      "Please wait #{duration} before requesting another verification email."
  end

  # Format duration in human-readable form for verification emails
  def format_verification_time_duration(seconds)
    return '0 seconds' if seconds <= 0

    if seconds < 60
      "#{seconds} second#{'s' unless seconds == 1}"
    elsif seconds < 3600
      minutes = (seconds / 60.0).ceil
      "#{minutes} minute#{'s' unless minutes == 1}"
    else
      hours = (seconds / 3600.0).ceil
      "#{hours} hour#{'s' unless hours == 1}"
    end
  end

  # Generate Redis key for verification email period counter
  def verification_period_key
    "#{current_user.uuid}:email_verification:period"
  end

  # Generate Redis key for verification email daily counter
  def verification_daily_key
    "#{current_user.uuid}:email_verification:daily"
  end

  # Get Redis client with email verification namespace
  def verification_redis
    @verification_redis ||= Redis::Namespace.new(
      VERIFICATION_EMAIL_LIMITS[:redis_namespace],
      redis: $redis
    )
  end

  # Log email verification rate limit denial
  def log_email_verification_rate_limit_denial(rate_limit_info)
    Rails.logger.warn('Email verification rate limit exceeded', {
                        user_uuid: current_user.uuid,
                        rate_limit_info:,
                        controller: self.class.name
                      })

    StatsD.increment('api.email_verification.rate_limit_exceeded', tags: {
                       'user_uuid' => current_user.uuid,
                       'controller' => self.class.name
                     })
  end
end
