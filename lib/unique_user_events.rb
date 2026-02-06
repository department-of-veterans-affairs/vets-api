# frozen_string_literal: true

require 'unique_user_events/service'

# Top-level module for Unique User Metrics system
#
# This module provides the main entry point for logging unique user events
# for analytics purposes. Events are tracked only once per user and include
# automatic DataDog metric increments for new events.
#
# @example Basic usage (OH facilities derived from user's facilities)
#   UniqueUserEvents.log_event(user: current_user, event_name: 'mhv_landing_page_accessed')
#
# @example With explicit facility IDs (OH facilities from operation context)
#   UniqueUserEvents.log_event(
#     user: current_user,
#     event_name: 'prescriptions_refill_requested',
#     event_facility_ids: ['757', '688']
#   )
#
# @example Check if event exists
#   UniqueUserEvents.event_logged?(user: current_user, event_name: 'secure_messages_accessed')
module UniqueUserEvents
  # Returned when feature is disabled or an error occurs
  EMPTY_RESPONSE = [].freeze

  # Log a unique user event
  #
  # This method buffers the event to Redis for batch processing. Also logs Oracle Health
  # events when the event is mapped to OH tracking.
  #
  # Oracle Health facility detection:
  # - Without event_facility_ids: OH facilities are derived from the user's facilities
  # - With event_facility_ids: OH facilities are determined from the provided IDs
  #   (useful when the operation context provides facility info, e.g., prescription refill station numbers)
  #
  # @param user [User] the authenticated User object
  # @param event_name [String] Name of the event being logged (max 50 chars)
  # @param event_facility_ids [Array<String>, nil] Optional facility IDs from the operation context.
  #   When provided, these are checked against tracked OH facilities instead of user's facilities.
  # @return [Array<String>] Array of event names that were buffered (empty if disabled)
  # @raise [ArgumentError] if parameters are invalid
  def self.log_event(user:, event_name:, event_facility_ids: nil)
    return EMPTY_RESPONSE unless Flipper.enabled?(:unique_user_metrics_logging)

    log_events(user:, event_names: [event_name], event_facility_ids:)
  end

  # Log multiple unique user events
  #
  # Pushes events to a Redis buffer for batch processing by UniqueUserMetricsProcessorJob.
  # Events include Oracle Health variants when applicable.
  #
  # Oracle Health facility detection:
  # - Without event_facility_ids: OH facilities are derived from the user's facilities
  # - With event_facility_ids: OH facilities are determined from the provided IDs
  #
  # @param user [User] the authenticated User object
  # @param event_names [Array<String>] Array of event names to log
  # @param event_facility_ids [Array<String>, nil] Optional facility IDs from the operation context.
  #   When provided, these are checked against tracked OH facilities instead of user's facilities.
  # @return [Array<String>] Array of event names that were buffered (empty if disabled)
  # @raise [ArgumentError] if parameters are invalid
  def self.log_events(user:, event_names:, event_facility_ids: nil)
    return EMPTY_RESPONSE unless Flipper.enabled?(:unique_user_metrics_logging)

    start_time = Time.current
    buffered_event_names = Service.buffer_events(user:, event_names:, event_facility_ids:)

    duration = (Time.current - start_time) * 1000.0
    StatsD.measure('uum.unique_user_metrics.log_events.duration', duration)
    buffered_event_names
  rescue ArgumentError
    raise
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
