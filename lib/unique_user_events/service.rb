# frozen_string_literal: true

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
    # @param user_id [String] UUID of the authenticated user
    # @param event_name [String] Name of the event being logged
    # @return [Boolean] true if new event was logged, false if already existed
    def self.log_event(user_id:, event_name:)
      # Record the event to database/cache
      new_event_created = MHVMetricsUniqueUserEvent.record_event(
        user_id:,
        event_name:
      )

      # Increment DataDog counter only for new events
      if new_event_created
        increment_statsd_counter(event_name)
        Rails.logger.info('UUM: New unique event logged with metrics', { user_id:, event_name: })
      else
        Rails.logger.debug('UUM: Duplicate event, no metrics increment', { user_id:, event_name: })
      end

      new_event_created
    rescue => e
      Rails.logger.error('UUM: Failed to log event', { user_id:, event_name:, error: e.message })
      # Don't raise - this is analytics, shouldn't break user flow
      false
    end

    # Check if an event has been logged for a user
    #
    # @param user_id [String] UUID of the user
    # @param event_name [String] Name of the event
    # @return [Boolean] true if event exists, false otherwise
    def self.event_logged?(user_id:, event_name:)
      MHVMetricsUniqueUserEvent.event_exists?(user_id:, event_name:)
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

    private_class_method :increment_statsd_counter
  end
end
