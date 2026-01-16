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
    return true if key_cached?(cache_key)

    # Check database if not in cache
    exists = exists?(user_id:, event_name:)

    # Cache the result only if record exists (saves memory for non-existent records)
    mark_key_cached(cache_key) if exists

    exists
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

  # Check if a cache key exists (presence-based caching)
  #
  # @param key [String] Cache key to check
  # @return [Boolean] true if key exists in cache, false otherwise
  def self.key_cached?(key)
    Rails.cache.exist?(key, namespace: CACHE_NAMESPACE)
  end

  # Mark a cache key as existing (sets key to indicate presence)
  #
  # @param key [String] Cache key to mark as cached
  def self.mark_key_cached(key)
    Rails.cache.write(key, true, namespace: CACHE_NAMESPACE, expires_in: CACHE_TTL)
  end

  private_class_method :validate_inputs, :key_cached?, :mark_key_cached
end
