# frozen_string_literal: true

require 'unique_user_events/service'

# Top-level module for Unique User Metrics system
#
# This module provides the main entry point for logging unique user events
# for analytics purposes. Events are tracked only once per user and include
# automatic DataDog metric increments for new events.
#
# @example Basic usage
#   UniqueUserEvents.log_event(user: current_user, event_name: 'mhv_landing_page_accessed')
#
# @example Check if event exists
#   UniqueUserEvents.event_logged?(user: current_user, event_name: 'secure_messages_accessed')
module UniqueUserEvents
  # Returned when feature is disabled or an error occurs
  EMPTY_RESPONSE = [].freeze

  # Log a unique user event
  #
  # This method buffers the event to Redis for batch processing. Also logs Oracle Health
  # events if the user belongs to OH facilities and the event is mapped.
  #
  # @param user [User] the authenticated User object
  # @param event_name [String] Name of the event being logged (max 50 chars)
  # @return [Array<String>] Array of event names that were buffered (empty if disabled)
  # @raise [ArgumentError] if parameters are invalid
  def self.log_event(user:, event_name:)
    return EMPTY_RESPONSE unless Flipper.enabled?(:unique_user_metrics_logging)

    log_events(user:, event_names: [event_name])
  end

  # Log multiple unique user events
  #
  # Pushes events to a Redis buffer for batch processing by UniqueUserMetricsProcessorJob.
  # Events include Oracle Health variants when applicable.
  #
  # @param user [User] the authenticated User object
  # @param event_names [Array<String>] Array of event names to log
  # @return [Array<String>] Array of event names that were buffered (empty if disabled)
  # @raise [ArgumentError] if parameters are invalid
  def self.log_events(user:, event_names:)
    return EMPTY_RESPONSE unless Flipper.enabled?(:unique_user_metrics_logging)

    start_time = Time.current
    buffered_event_names = Service.buffer_events(user:, event_names:)

    duration = (Time.current - start_time) * 1000.0
    StatsD.measure('uum.unique_user_metrics.log_events.duration', duration)
    buffered_event_names
  rescue ArgumentError
    raise # Re-raise validation errors - these are programming bugs that should fail fast
  rescue => e
    Rails.logger.error("UUM: Failed during log_events - Error: #{e.message}")
    EMPTY_RESPONSE
  end

  # Check if an event has already been logged for a user
  #
  # @param user [User] the authenticated User object
  # @param event_name [String] Name of the event to check
  # @return [Boolean] true if event exists, false otherwise
  # @raise [ArgumentError] if parameters are invalid
  def self.event_logged?(user:, event_name:)
    Service.event_logged?(user:, event_name:)
  end
end
