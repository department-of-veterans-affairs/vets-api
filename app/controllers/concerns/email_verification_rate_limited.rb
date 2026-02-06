# frozen_string_literal: true

module EmailVerificationRateLimited
  extend ActiveSupport::Concern

  VERIFICATION_EMAIL_LIMITS = { per_period: 1, period: 5.minutes, daily_limit: 5, daily_period: 24.hours,
                                redis_namespace: 'email_verification_rate_limit' }.freeze

  def enforce_email_verification_rate_limit!
    return unless email_verification_rate_limit_exceeded?

    rate_limit_info = get_email_verification_rate_limit_info
    log_email_verification_rate_limit_denial(rate_limit_info)
    retry_after = time_until_next_verification_allowed
    response.headers['Retry-After'] = retry_after.to_s if response

    raise Common::Exceptions::TooManyRequests
  rescue Redis::BaseConnectionError => e
    Rails.logger.warn('Redis connection error in email verification rate limit enforcement', { error: e.message })
    nil
  end

  def email_verification_rate_limit_exceeded?
    verification_period_count >= VERIFICATION_EMAIL_LIMITS[:per_period] ||
      verification_daily_count >= VERIFICATION_EMAIL_LIMITS[:daily_limit]
  end

  def increment_email_verification_rate_limit!
    verification_redis.multi do |multi|
      multi.incr(verification_period_key)
      multi.expire(verification_period_key, VERIFICATION_EMAIL_LIMITS[:period].to_i)
      multi.incr(verification_daily_key)
      multi.expire(verification_daily_key, VERIFICATION_EMAIL_LIMITS[:daily_period].to_i)
    end

    clear_verification_rate_limit_cache
  rescue Redis::BaseConnectionError => e
    Rails.logger.warn('Redis connection error in email verification rate limit increment', { error: e.message })
    nil
  end

  def reset_email_verification_rate_limit!
    verification_redis.del(verification_period_key, verification_daily_key)
    clear_verification_rate_limit_cache
  end

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

  def verification_period_count
    @verification_period_count ||= verification_redis.get(verification_period_key).to_i
  end

  def verification_daily_count
    @verification_daily_count ||= verification_redis.get(verification_daily_key).to_i
  end

  def clear_verification_rate_limit_cache
    @verification_period_count = nil
    @verification_daily_count = nil
  end

  def time_until_next_verification_allowed
    ttl_period = verification_redis.ttl(verification_period_key)
    ttl_daily = verification_redis.ttl(verification_daily_key)
    [ttl_period, ttl_daily, 0].max
  rescue Redis::BaseConnectionError => e
    Rails.logger.warn('Redis connection error in email verification rate limit ttl lookup', { error: e.message })
    0
  end

  def build_verification_rate_limit_message
    seconds = time_until_next_verification_allowed

    if seconds.nil? || seconds <= 0
      'Too many requests. Please wait before trying again.'
    else
      duration = format_verification_time_duration(seconds)
      "Verification email limit reached. Wait #{duration} to try again."
    end
  end

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

  def verification_period_key
    "#{current_user.uuid}:email_verification:period"
  end

  def verification_daily_key
    "#{current_user.uuid}:email_verification:daily"
  end

  def verification_redis
    @verification_redis ||= Redis::Namespace.new(VERIFICATION_EMAIL_LIMITS[:redis_namespace], redis: $redis)
  end

  def log_email_verification_rate_limit_denial(rate_limit_info)
    tags = { 'user_uuid' => current_user.uuid, 'controller' => self.class.name }
    Rails.logger.warn('Email verification rate limit exceeded', {
                        user_uuid: current_user.uuid, rate_limit_info:, controller: self.class.name
                      })
    StatsD.increment('api.email_verification.rate_limit_exceeded', tags:)
  end
end
