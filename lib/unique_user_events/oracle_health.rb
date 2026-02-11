# frozen_string_literal: true

require 'unique_user_events/event_registry'

module UniqueUserEvents
  # Oracle Health specific functionality for unique user metrics
  #
  # This module handles the generation of Oracle Health site-specific events
  # based on user facility registrations and tracked events.
  module OracleHealth
    # Tracked facility IDs that should generate OH events
    # Loaded from Settings.unique_user_metrics.oracle_health_tracked_facility_ids
    # Validates that all IDs are 3-digit numbers (VA facility ID format)
    # Returns empty array if validation fails to avoid crashing metrics code
    # Uses Array() to safely handle scalar values from environment variable overrides
    TRACKED_FACILITY_IDS = begin
      raw_value = Settings.unique_user_metrics&.oracle_health_tracked_facility_ids
      ids = Array(raw_value)

      # Validate facility IDs are 3-digit numbers
      invalid_ids = ids.reject { |id| id.to_s =~ /^\d{3}$/ }
      if invalid_ids.any?
        Rails.logger.error(
          'UniqueUserEvents::OracleHealth: Invalid facility IDs in ' \
          "Settings.unique_user_metrics.oracle_health_tracked_facility_ids: #{invalid_ids.join(', ')}. " \
          'VA facility IDs must be 3-digit numbers. Using empty array.'
        )
        [].freeze
      else
        ids.map(&:to_s).freeze
      end
    end

    # Event suffix for Oracle Health facility-specific events (explicit facility context)
    OH_EVENT_SUFFIX = '_oh_'

    # Events that should generate Oracle Health site-specific events
    # Uses EventRegistry constants to avoid string duplication
    TRACKED_EVENTS = [
      EventRegistry::MEDICAL_RECORDS_ALLERGIES_ACCESSED,
      EventRegistry::MEDICAL_RECORDS_VACCINES_ACCESSED,
      EventRegistry::MEDICAL_RECORDS_LABS_ACCESSED,
      EventRegistry::MEDICAL_RECORDS_NOTES_ACCESSED,
      EventRegistry::MEDICAL_RECORDS_VITALS_ACCESSED,
      EventRegistry::MEDICAL_RECORDS_CONDITIONS_ACCESSED
    ].freeze

    # Generate facility-specific events for a user and event
    #
    # This method has two modes of operation:
    #
    # 1. With event_facility_ids (explicit facility context):
    #    - Generates `#{event_name}_oh_#{facility_id}` for matching facilities
    #    - Does NOT check TRACKED_EVENTS - any event can generate site-specific variants
    #    - Use this when the operation context provides facility info (e.g., prescription refill)
    #    - Validates facilities are both tracked AND actual OH facilities for the user
    #
    # 2. Without event_facility_ids (user-based):
    #    - Generates `#{event_name}_oh_site_#{facility_id}` for matching facilities
    #    - Only generates events for event names in TRACKED_EVENTS
    #    - Uses the user's Cerner facilities filtered by tracked facilities
    #
    # @param user [User] the authenticated User object
    # @param event_name [String] Name of the original event
    # @param event_facility_ids [Array<String>, nil] Optional facility IDs from operation context.
    #   When provided, these are checked against tracked facilities and user's cerner_facility_ids,
    #   and TRACKED_EVENTS validation is bypassed (caller is responsible for appropriate usage).
    # @return [Array<String>] Array of facility-specific event names to be logged
    def self.generate_events(user:, event_name:, event_facility_ids: nil)
      return [] unless Flipper.enabled?(:mhv_oh_unique_user_metrics_logging)

      if event_facility_ids
        matching_facilities = filter_tracked_oh_facilities(event_facility_ids, user)
        matching_facilities.map { |facility_id| "#{event_name}#{OH_EVENT_SUFFIX}#{facility_id}" }
      else
        return [] unless TRACKED_EVENTS.include?(event_name)

        matching_facilities = get_user_tracked_facilities(user)
        matching_facilities.map { |facility_id| "#{event_name}_oh_site_#{facility_id}" }
      end
    end

    # Filter provided facility IDs to only include tracked OH facilities
    # that are also confirmed as Cerner/OH facilities for this user
    #
    # @param facility_ids [Array<String>] Array of facility IDs to filter
    # @param user [User] the authenticated User object
    # @return [Array<String>] Array of matching facility IDs
    def self.filter_tracked_oh_facilities(facility_ids, user)
      return [] if facility_ids.blank?

      normalized_ids = facility_ids.map(&:to_s)
      tracked_user_facilities = get_user_tracked_facilities(user)
      normalized_ids & tracked_user_facilities
    end

    # Get user's OH facilities that match tracked facilities
    #
    # @param user [User] the authenticated User object
    # @return [Array<String>] Array of matching facility IDs
    def self.get_user_tracked_facilities(user)
      cerner_ids = (user.cerner_facility_ids || []).map(&:to_s)
      cerner_ids & TRACKED_FACILITY_IDS
    end

    private_class_method :get_user_tracked_facilities, :filter_tracked_oh_facilities
  end
end
