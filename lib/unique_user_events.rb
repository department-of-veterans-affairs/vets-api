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
  # Log a unique user event with DataDog metrics
  #
  # This method records the event in the database (if new) and increments
  # a DataDog counter for unique user metrics analytics. Also logs Oracle Health
  # events if the user belongs to OH facilities and the event is mapped.
  #
  # @param user [User] the authenticated User object
  # @param event_name [String] Name of the event being logged (max 50 chars)
  #   Use EventRegistry constants (e.g., EventRegistry::PRESCRIPTIONS_ACCESSED)
  #   instead of raw strings to prevent typos and enable IDE autocomplete.
  # @return [Array<Hash>] Array of event results
  # @raise [ArgumentError] if parameters are invalid
  #
  # @example Using EventRegistry constants (recommended)
  #   UniqueUserEvents.log_event(
  #     user: current_user,
  #     event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED
  #   )
  def self.log_event(user:, event_name:)
    return [Service.build_disabled_result(event_name)] unless Flipper.enabled?(:unique_user_metrics_logging)

    start_time = Time.current
    result = Service.log_event(user:, event_name:)
    duration = (Time.current - start_time) * 1000.0 # Convert to milliseconds

    StatsD.measure('uum.unique_user_metrics.log_event.duration', duration, tags: ["event_name:#{event_name}"])
    result
  rescue => e
    Rails.logger.error("UUM: Failed during log_event - Event: #{event_name}, Error: #{e.message}")
    [Service.build_error_result(event_name)]
  end

  # Log multiple unique user events with DataDog metrics
  #
  # This method records multiple events in the database (if new) and increments
  # DataDog counters for unique user metrics analytics. Also logs Oracle Health
  # events if the user belongs to OH facilities and the events are mapped.
  #
  # @param user [User] the authenticated User object
  # @param event_names [Array<String>] Array of event names to log
  #   Use EventRegistry constants (e.g., EventRegistry::PRESCRIPTIONS_ACCESSED)
  #   instead of raw strings to prevent typos and enable IDE autocomplete.
  # @return [Array<Hash>] Flattened array of all event results
  # @raise [ArgumentError] if parameters are invalid
  #
  # @example Using EventRegistry constants (recommended)
  #   UniqueUserEvents.log_events(
  #     user: current_user,
  #     event_names: [
  #       UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
  #       UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_LABS_ACCESSED
  #     ]
  #   )
  def self.log_events(user:, event_names:)
    event_names.flat_map do |event_name|
      log_event(user:, event_name:)
    end
  end

  # Check if an event has already been logged for a user
  #
  # @param user [User] the authenticated User object
  # @param event_name [String] Name of the event to check
  #   Use EventRegistry constants (e.g., EventRegistry::PRESCRIPTIONS_ACCESSED)
  #   instead of raw strings to prevent typos and enable IDE autocomplete.
  # @return [Boolean] true if event exists, false otherwise
  # @raise [ArgumentError] if parameters are invalid
  #
  # @example
  #   if UniqueUserEvents.event_logged?(
  #     user: current_user,
  #     event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED
  #   )
  #     # User has already accessed prescriptions
  #   end
  def self.event_logged?(user:, event_name:)
    Service.event_logged?(user:, event_name:)
  end
end
