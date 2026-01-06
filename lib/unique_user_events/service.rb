# frozen_string_literal: true

require 'unique_user_events/event_registry'
require 'unique_user_events/oracle_health'

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
  # Service class for MHV Unique User Metrics
  #
  # This service provides the core business logic for logging and checking unique user events
  # for MHV Portal analytics. It integrates with the MHVMetricsUniqueUserEvent model and provides
  # DataDog metric increments for new events.
  class Service
    # StatsD key prefix for unique user metrics
    STATSD_KEY_PREFIX = 'uum.unique_user_metrics'

    # Log a unique user event with DataDog metrics
    #
    # @param user [User] the authenticated User object
    # @param event_name [String] Name of the event being logged
    #   Use EventRegistry constants (e.g., EventRegistry::PRESCRIPTIONS_ACCESSED)
    #   instead of raw strings to prevent typos and enable IDE autocomplete.
    # @return [Array<Hash>] Array of event results with event_name, status, and new_event keys
    # @raise [ArgumentError] if event_name is not in the registry
    #
    # @example Using EventRegistry constants (recommended)
    #   UniqueUserEvents::Service.log_event(
    #     user: current_user,
    #     event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED
    #   )
    def self.log_event(user:, event_name:)
      EventRegistry.validate_event!(event_name)
      user_id = extract_user_id(user)

      # Get all events to be logged (original + OH events)
      events_to_log = get_all_events_to_log(user:, event_name:)

      # Increment StatsD counter for the total number of events to log
      begin
        StatsD.increment("#{STATSD_KEY_PREFIX}.logged_event", events_to_log.size, tags: ["event_name:#{event_name}"])
      rescue => e
        Rails.logger.error('UUM: Failed to increment StatsD logged_event counter', { event_name:, error: e.message })
        # Don't raise - metrics failure shouldn't break the main flow
      end

      # Log each event and collect results
      events_to_log.map do |event_name_to_log|
        log_single_event(user_id:, event_name: event_name_to_log)
      end
    rescue ArgumentError
      # Re-raise validation errors - these are programmer errors
      raise
    rescue => e
      Rails.logger.error('UUM: Failed to log event', { user_id:, event_name:, error: e.message })
      # Don't raise - this is analytics, shouldn't break user flow
      false
    end

    # Check if an event has been logged for a user
    #
    # @param user [User] the authenticated User object
    # @param event_name [String] Name of the event
    #   Use EventRegistry constants (e.g., EventRegistry::PRESCRIPTIONS_ACCESSED)
    #   instead of raw strings to prevent typos and enable IDE autocomplete.
    # @return [Boolean] true if event exists, false otherwise
    # @raise [ArgumentError] if event_name is not in the registry
    def self.event_logged?(user:, event_name:)
      EventRegistry.validate_event!(event_name)
      user_id = extract_user_id(user)
      MHVMetricsUniqueUserEvent.event_exists?(user_id:, event_name:)
    rescue ArgumentError
      # Re-raise validation errors - these are programmer errors
      raise
    rescue => e
      Rails.logger.error('UUM: Failed to check event', { user_id:, event_name:, error: e.message })
      # Don't raise - return false if we can't check
      false
    end

    # Private method to increment StatsD counter for new unique events
    #
    # @param event_name [String] Name of the event
    def self.increment_statsd_counter(event_name)
      StatsD.increment("#{STATSD_KEY_PREFIX}.event", tags: ["event_name:#{event_name}"])
    rescue => e
      Rails.logger.error('UUM: Failed to increment StatsD counter', { event_name:, error: e.message })
      # Don't raise - metrics failure shouldn't break the main flow
    end

    # Get all events to be logged (original + Oracle Health events)
    #
    # @param user [User] the authenticated User object
    # @param event_name [String] Name of the original event
    # @return [Array<String>] Array of all event names to be logged
    def self.get_all_events_to_log(user:, event_name:)
      events = [event_name]

      # Add Oracle Health events if applicable
      oh_events = OracleHealth.generate_events(user:, event_name:)
      events.concat(oh_events)

      events
    end

    # Log a single event.
    #
    # @param user_id [String] User account UUID
    # @param event_name [String] Name of the event to log
    # @return [Hash] Event result hash with event_name, status, and new_event
    def self.log_single_event(user_id:, event_name:)
      event_created = MHVMetricsUniqueUserEvent.record_event(user_id:, event_name:)

      if event_created
        increment_statsd_counter(event_name)
        Rails.logger.info('UUM: New event logged', { user_id:, event_name: })
      end

      build_event_result(event_name, event_created)
    rescue => e
      Rails.logger.error('UUM: Failed to log event', {
                           user_id:,
                           event_name:,
                           error: e.message
                         })
      build_error_result(event_name)
    end

    # Extract user ID from user object
    #
    # @param user [User] the authenticated User object
    # @return [String] User account UUID
    def self.extract_user_id(user)
      user.user_account_uuid
    end

    # Build event result hash for API response
    #
    # @param event_name [String] Name of the event
    # @param was_created [Boolean] Whether the event was newly created
    # @return [Hash] Event result hash
    def self.build_event_result(event_name, was_created)
      {
        event_name:,
        status: was_created ? 'created' : 'exists',
        new_event: was_created
      }
    end

    # Build error result hash for API response
    #
    # @param event_name [String] Name of the event
    # @return [Hash] Error result hash
    def self.build_error_result(event_name)
      {
        event_name:,
        status: 'error',
        new_event: false,
        error: 'Failed to process event'
      }
    end

    # Build disabled result hash for API response
    #
    # @param event_name [String] Name of the event
    # @return [Hash] Disabled result hash
    def self.build_disabled_result(event_name)
      {
        event_name:,
        status: 'disabled',
        new_event: false
      }
    end

    # Build invalid result hash for API response
    #
    # @param event_name [String] Name of the event
    # @return [Hash] Invalid result hash
    def self.build_invalid_result(event_name)
      {
        event_name:,
        status: 'invalid',
        new_event: false
      }
    end

    private_class_method :increment_statsd_counter, :log_single_event,
                         :build_event_result

    # Build buffered result hash for API response
    #
    # @param event_name [String] Name of the event
    # @return [Hash] Buffered result hash
    def self.build_buffered_result(event_name)
      {
        event_name:,
        status: 'buffered',
        new_event: nil # Intentionally nil; new_event will be determined during later batch processing
      }
    end
  end
end
