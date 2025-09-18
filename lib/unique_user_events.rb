# frozen_string_literal: true

require 'unique_user_events/service'

# Top-level module for Unique User Metrics system
#
# This module provides the main entry point for logging unique user events
# for analytics purposes. Events are tracked only once per user and include
# automatic DataDog metric increments for new events.
#
# @example Basic usage
#   UniqueUserEvents.log_event(user_id: current_user.uuid, event_name: 'mhv_landing_page_accessed')
#
# @example Check if event exists
#   UniqueUserEvents.event_logged?(user_id: current_user.uuid, event_name: 'secure_messages_accessed')
module UniqueUserEvents
  # Log a unique user event with DataDog metrics
  #
  # This method records the event in the database (if new) and increments
  # a DataDog counter for unique user metrics analytics.
  #
  # @param user_id [String] UUID of the authenticated user
  # @param event_name [String] Name of the event being logged (max 50 chars)
  # @return [Boolean] true if new event was logged, false if already existed or feature disabled
  # @raise [ArgumentError] if parameters are invalid
  #
  # @example
  #   UniqueUserEvents.log_event(user_id: user.uuid, event_name: 'appointments_viewed')
  def self.log_event(user_id:, event_name:)
    return false unless Flipper.enabled?(:unique_user_metrics_logging)

    start_time = Time.current
    result = Service.log_event(user_id:, event_name:)
    duration = (Time.current - start_time) * 1000.0 # Convert to milliseconds

    StatsD.measure('uum.unique_user_metrics.log_event.duration', duration, tags: ["event_name:#{event_name}"])
    result
  rescue => e
    Rails.logger.error("UUM: Failed during log_event - Event: #{event_name}, Error: #{e.message}")
    false
  end

  # Check if an event has already been logged for a user
  #
  # @param user_id [String] UUID of the user
  # @param event_name [String] Name of the event to check
  # @return [Boolean] true if event exists, false otherwise
  # @raise [ArgumentError] if parameters are invalid
  #
  # @example
  #   if UniqueUserEvents.event_logged?(user_id: user.uuid, event_name: 'mhv_landing_accessed')
  #     # User has already accessed MHV landing page
  #   end
  def self.event_logged?(user_id:, event_name:)
    Service.event_logged?(user_id:, event_name:)
  end
end
