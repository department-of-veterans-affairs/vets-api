# frozen_string_literal: true

# Unique User Metrics event tracking model for MHV Portal
#
# This model tracks unique user events for analytics purposes. Each record represents
# the first time a specific user performed a specific event (e.g., viewed MHV landing page,
# accessed secure messages, etc.).
#
# Design notes:
# - Uses compound unique index (user_id, event_name) to ensure one record per user per event
# - No foreign key constraint on user_id for performance and historical data preservation
# - Includes Redis caching to minimize database reads for duplicate event checks
class MHVMetricsUniqueUserEvent < ApplicationRecord
  include RedisCaching

  # Cache configuration
  REDIS_CONFIG_KEY = REDIS_CONFIG[:unique_user_metrics]
  CACHE_NAMESPACE = 'unique_user_metrics'
  CACHE_TTL = REDIS_CONFIG_KEY[:each_ttl]

  # Configure Redis caching for duplicate event checks
  redis_config REDIS_CONFIG_KEY

  # Active Record Validations
  validates :user_id, presence: true
  validates :event_name, presence: true, length: { maximum: 50 }

  # Class methods for event logging and checking

  # Check if a specific event has already been logged for a user
  #
  # @param user_id [String] UUID of the user
  # @param event_name [String] Name of the event to check
  # @return [Boolean] true if event exists, false otherwise
  def self.event_exists?(user_id:, event_name:)
    validate_inputs(user_id, event_name)

    cache_key = generate_cache_key(user_id, event_name)

    # Check Redis cache first for performance
    cached_result = get_cached(cache_key)
    return true if cached_result == 'exists'

    # Check database if not in cache
    exists = exists?(user_id:, event_name:)

    # Cache the result to avoid future database queries
    set_cached(cache_key, exists ? 'exists' : 'not_exists')

    exists
  end

  # Record a unique user event (creates record only if it doesn't exist)
  #
  # @param user_id [String] UUID of the user
  # @param event_name [String] Name of the event to record
  # @return [Boolean] true if new event was created, false if already existed
  # @raise [ActiveRecord::RecordInvalid] if validation fails
  def self.record_event(user_id:, event_name:)
    validate_inputs(user_id, event_name)

    cache_key = generate_cache_key(user_id, event_name)

    # Check Redis cache first - if exists, skip database entirely
    cached_result = get_cached(cache_key)
    if cached_result == 'exists'
      Rails.logger.debug { "UUM: Event found in cache - User: #{user_id}, Event: #{event_name}" }
      return false
    end

    # Try to insert directly - optimistic approach
    begin
      create!(user_id:, event_name:)

      # Cache that this event now exists
      set_cached(cache_key, 'exists')

      Rails.logger.info("UUM: New unique event recorded - User: #{user_id}, Event: #{event_name}")
      true # NEW EVENT - top-level library should log to statsd
    rescue ActiveRecord::RecordNotUnique
      # Event already exists in database
      set_cached(cache_key, 'exists')

      Rails.logger.debug { "UUM: Duplicate event found in database - User: #{user_id}, Event: #{event_name}" }
      false # DUPLICATE EVENT - top-level library should NOT log to statsd
    end
  end

  # Generate consistent cache key for user/event combination
  #
  # @param user_id [String] UUID of the user
  # @param event_name [String] Name of the event
  # @return [String] Cache key
  def self.generate_cache_key(user_id, event_name)
    "#{user_id}:#{event_name}"
  end

  # Validate input parameters
  #
  # @param user_id [String] UUID of the user
  # @param event_name [String] Name of the event
  # @raise [ArgumentError] if inputs are invalid
  def self.validate_inputs(user_id, event_name)
    raise ArgumentError, 'user_id is required' if user_id.blank?
    raise ArgumentError, 'event_name is required' if event_name.blank?
    raise ArgumentError, 'event_name must be 50 characters or less' if event_name.length > 50
  end

  # Override the default cache methods to work with simple string values
  def self.get_cached(key)
    Rails.cache.read(key, namespace: CACHE_NAMESPACE)
  end

  def self.set_cached(key, value)
    Rails.cache.write(key, value, namespace: CACHE_NAMESPACE, expires_in: CACHE_TTL)
  end

  private_class_method :generate_cache_key, :validate_inputs, :get_cached, :set_cached
end
