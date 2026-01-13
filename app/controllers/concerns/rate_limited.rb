# frozen_string_literal: true

# RateLimited concern provides Redis-based rate limiting functionality for controllers.
#
# Usage:
#   class MyController < ApplicationController
#     include RateLimited
#
#     rate_limit :my_action, per_period: 1, period: 5.minutes, daily_limit: 5
#
#     def my_action
#       enforce_rate_limit!(:my_action)
#       # ... rest of action
#     end
#   end
#
# The concern handles:
# - Period-based limits (e.g., 1 request per 5 minutes)
# - Daily limits (e.g., 5 requests per 24 hours)
# - Redis storage with automatic expiration
# - Error responses with retry-after information
# - Rate limit reset functionality
#
module RateLimited
  extend ActiveSupport::Concern

  included do
    class_attribute :rate_limit_configs, default: {}
  end

  class_methods do
    # Configure rate limiting for an action
    #
    # @param action_name [Symbol] Name of the action to rate limit
    # @param per_period [Integer] Number of requests allowed per period
    # @param period [ActiveSupport::Duration] Time period for rate limit
    # @param daily_limit [Integer] Maximum requests allowed per 24 hours
    # @param redis_namespace [String] Redis namespace for keys (optional)
    def rate_limit(action_name, per_period:, period:, daily_limit:, redis_namespace: nil)
      redis_namespace ||= "#{name&.underscore&.tr('/', '_') || 'anonymous'}_rate_limit"

      self.rate_limit_configs = rate_limit_configs.merge(
        action_name => {
          per_period:,
          period:,
          daily_limit:,
          daily_period: 24.hours,
          redis_namespace:
        }
      )
    end
  end

  # Enforce rate limiting for the specified action
  # Renders error response and returns if rate limit exceeded
  #
  # @param action_name [Symbol] Name of the configured rate limit
  def enforce_rate_limit!(action_name)
    config = rate_limit_configs[action_name]
    raise ArgumentError, "No rate limit configured for #{action_name}" unless config

    return unless rate_limit_exceeded?(action_name)

    rate_limit_info = get_rate_limit_info(action_name)
    log_rate_limit_denial(action_name, rate_limit_info)

    render json: {
      errors: [
        {
          title: 'Rate Limit Exceeded',
          detail: build_rate_limit_error_message(action_name),
          code: 'RATE_LIMIT_EXCEEDED',
          status: '429',
          meta: build_rate_limit_meta(action_name, config)
        }
      ]
    }, status: :too_many_requests
  end

  # Check rate limit and increment counters if not exceeded
  # Use this when you want to both check and increment in one call
  #
  # @param action_name [Symbol] Name of the configured rate limit
  # @return [Boolean] true if request is allowed (limit not exceeded)
  def check_and_increment_rate_limit!(action_name)
    return false if rate_limit_exceeded?(action_name)

    increment_rate_limit!(action_name)
    true
  end

  # Check if rate limit is exceeded for the given action
  #
  # @param action_name [Symbol] Name of the configured rate limit
  # @return [Boolean] true if rate limit exceeded
  def rate_limit_exceeded?(action_name)
    config = rate_limit_configs[action_name]
    return false unless config

    period_count(action_name) >= config[:per_period] ||
      daily_count(action_name) >= config[:daily_limit]
  end

  # Increment rate limit counters for the given action
  #
  # @param action_name [Symbol] Name of the configured rate limit
  def increment_rate_limit!(action_name)
    config = rate_limit_configs[action_name]
    return unless config

    redis_client = redis(action_name)

    # Increment period counter
    redis_client.multi do |multi|
      multi.incr(period_key(action_name))
      multi.expire(period_key(action_name), config[:period].to_i)
    end

    # Increment daily counter
    redis_client.multi do |multi|
      multi.incr(daily_key(action_name))
      multi.expire(daily_key(action_name), config[:daily_period].to_i)
    end

    # Clear cached counts
    clear_rate_limit_cache(action_name)
  end

  # Reset rate limit counters for the given action
  #
  # @param action_name [Symbol] Name of the configured rate limit
  def reset_rate_limit!(action_name)
    redis_client = redis(action_name)
    redis_client.del(period_key(action_name), daily_key(action_name))
    clear_rate_limit_cache(action_name)
  end

  # Get current rate limit information
  #
  # @param action_name [Symbol] Name of the configured rate limit
  # @return [Hash] Rate limit statistics
  def get_rate_limit_info(action_name)
    config = rate_limit_configs[action_name]
    return {} unless config

    {
      period_count: period_count(action_name),
      daily_count: daily_count(action_name),
      max_per_period: config[:per_period],
      max_daily: config[:daily_limit],
      period_seconds: config[:period].to_i,
      time_until_reset: time_until_next_allowed_seconds(action_name)
    }
  end

  private

  # Get current period count for action
  def period_count(action_name)
    instance_variable_get(:"@period_count_#{action_name}") ||
      instance_variable_set(:"@period_count_#{action_name}", redis(action_name).get(period_key(action_name)).to_i)
  end

  # Get current daily count for action
  def daily_count(action_name)
    instance_variable_get(:"@daily_count_#{action_name}") ||
      instance_variable_set(:"@daily_count_#{action_name}", redis(action_name).get(daily_key(action_name)).to_i)
  end

  # Clear cached rate limit counts
  def clear_rate_limit_cache(action_name)
    instance_variable_set(:"@period_count_#{action_name}", nil)
    instance_variable_set(:"@daily_count_#{action_name}", nil)
  end

  # Get seconds until next allowed request
  def time_until_next_allowed_seconds(action_name)
    config = rate_limit_configs[action_name]
    return 0 unless config

    redis_client = redis(action_name)
    ttl_period = redis_client.ttl(period_key(action_name))
    ttl_daily = redis_client.ttl(daily_key(action_name))

    # Return the larger of the two TTLs
    [ttl_period, ttl_daily].max
  end

  # Build human-readable error message
  def build_rate_limit_error_message(action_name)
    seconds = time_until_next_allowed_seconds(action_name)
    duration = format_time_duration(seconds)

    'You have exceeded the maximum number of requests allowed. ' \
      "Please wait #{duration} before trying again."
  end

  # Build rate limit metadata for error response
  def build_rate_limit_meta(action_name, config)
    {
      retry_after: time_until_next_allowed_seconds(action_name),
      per_period_limit: config[:per_period],
      period_seconds: config[:period].to_i,
      daily_limit: config[:daily_limit]
    }
  end

  # Format duration in human-readable form
  def format_time_duration(seconds)
    return '0 seconds' if seconds <= 0

    if seconds < 60
      "#{seconds} second#{'s' unless seconds == 1}"
    elsif seconds < 3600
      minutes = seconds / 60
      "#{minutes} minute#{'s' unless minutes == 1}"
    else
      hours = seconds / 3600
      "#{hours} hour#{'s' unless hours == 1}"
    end
  end

  # Generate Redis key for period counter
  def period_key(action_name)
    "#{current_user.uuid}:#{action_name}:period"
  end

  # Generate Redis key for daily counter
  def daily_key(action_name)
    "#{current_user.uuid}:#{action_name}:daily"
  end

  # Get Redis client with namespace
  def redis(action_name)
    config = rate_limit_configs[action_name]
    namespace = config&.dig(:redis_namespace) || 'rate_limit'

    instance_variable_get(:"@redis_#{action_name}") ||
      instance_variable_set(:"@redis_#{action_name}", Redis::Namespace.new(namespace, redis: $redis))
  end

  # Log rate limit denial
  def log_rate_limit_denial(action_name, rate_limit_info)
    Rails.logger.warn('Rate limit exceeded', {
                        user_uuid: current_user.uuid,
                        action: action_name,
                        rate_limit_info:,
                        controller: self.class.name
                      })

    StatsD.increment('api.rate_limit_exceeded', tags: {
                       'user_uuid' => current_user.uuid,
                       'action' => action_name.to_s,
                       'controller' => self.class.name
                     })
  end
end
