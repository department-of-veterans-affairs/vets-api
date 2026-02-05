# frozen_string_literal: true

require 'unique_user_events/event_registry'
require 'unique_user_events/oracle_health'
require 'unique_user_events/buffer'

module UniqueUserEvents
  # Service class for MHV Unique User Metrics
  #
  # This service provides the core business logic for logging and checking unique user events
  # for MHV Portal analytics. It validates events, expands Oracle Health variants, and
  # buffers events to Redis for batch processing.
  class Service
    # Buffer events to Redis for batch processing
    #
    # Validates event names, expands Oracle Health events, and pushes all events
    # to the Redis buffer in a single call.
    #
    # Oracle Health facility detection:
    # - Without event_facility_ids: OH facilities are derived from the user's facilities
    # - With event_facility_ids: OH facilities are determined from the provided IDs
    #
    # @param user [User] the authenticated User object
    # @param event_names [Array<String>] Array of event names to buffer
    # @param event_facility_ids [Array<String>, nil] Optional facility IDs from operation context.
    #   When provided, these are checked against tracked OH facilities instead of user's facilities.
    # @return [Array<String>] Array of all event names that were buffered (including OH events)
    # @raise [ArgumentError] if any event_name is not in the registry
    def self.buffer_events(user:, event_names:, event_facility_ids: nil)
      user_id = extract_user_id(user)

      all_events = []
      buffered_event_names = []

      event_names.each do |event_name|
        EventRegistry.validate_event!(event_name)
        event_names_to_buffer = get_all_events_to_log(user:, event_name:, event_facility_ids:)

        event_names_to_buffer.each do |name|
          all_events << { user_id:, event_name: name }
          buffered_event_names << name
        end
      end

      Buffer.push_batch(all_events)

      buffered_event_names
    end

    # Check if an event has been logged for a user
    #
    # @param user [User] the authenticated User object
    # @param event_name [String] Name of the event
    # @return [Boolean] true if event exists, false otherwise
    # @raise [ArgumentError] if event_name is not in the registry
    def self.event_logged?(user:, event_name:)
      EventRegistry.validate_event!(event_name)
      user_id = extract_user_id(user)
      MHVMetricsUniqueUserEvent.event_exists?(user_id:, event_name:)
    rescue ArgumentError
      raise
    rescue => e
      Rails.logger.error('UUM: Failed to check event', { user_id:, event_name:, error: e.message })
      false
    end

    # Get all events to be logged (original + Oracle Health events)
    #
    # @param user [User] the authenticated User object
    # @param event_name [String] Name of the original event
    # @param event_facility_ids [Array<String>, nil] Optional facility IDs from operation context
    # @return [Array<String>] Array of all event names to be logged
    def self.get_all_events_to_log(user:, event_name:, event_facility_ids:)
      events = [event_name]

      oh_events = OracleHealth.generate_events(user:, event_name:, event_facility_ids:)

      events.concat(oh_events)
      events
    end

    # Extract user ID from user object
    #
    # @param user [User] the authenticated User object
    # @return [String] User account UUID
    def self.extract_user_id(user)
      user.user_account_uuid || user.uuid
    end

    private_class_method :get_all_events_to_log, :extract_user_id
  end
end
