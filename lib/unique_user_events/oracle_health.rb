# frozen_string_literal: true

require 'unique_user_events/event_registry'

module UniqueUserEvents
  # Oracle Health specific functionality for unique user metrics
  #
  # This module handles the generation of Oracle Health site-specific events
  # based on user facility registrations and tracked events.
  module OracleHealth
    # Tracked facility IDs that should generate OH events
    TRACKED_FACILITY_IDS = %w[757].freeze

    # Events that should generate Oracle Health site-specific events
    # Uses EventRegistry constants to avoid string duplication
    TRACKED_EVENTS = [
      EventRegistry::SECURE_MESSAGING_MESSAGE_SENT,
      EventRegistry::APPOINTMENTS_ACCESSED,
      EventRegistry::MEDICAL_RECORDS_ALLERGIES_ACCESSED,
      EventRegistry::MEDICAL_RECORDS_VACCINES_ACCESSED,
      EventRegistry::MEDICAL_RECORDS_LABS_ACCESSED,
      EventRegistry::MEDICAL_RECORDS_NOTES_ACCESSED,
      EventRegistry::MEDICAL_RECORDS_VITALS_ACCESSED,
      EventRegistry::MEDICAL_RECORDS_CONDITIONS_ACCESSED
    ].freeze

    # Generate Oracle Health events for a user and event
    #
    # @param user [User] the authenticated User object
    # @param event_name [String] Name of the original event
    # @return [Array<String>] Array of OH event names to be logged
    def self.generate_events(user:, event_name:)
      return [] unless TRACKED_EVENTS.include?(event_name)

      matching_facilities = get_user_tracked_facilities(user)
      matching_facilities.map do |facility_id|
        "#{event_name}_oh_site_#{facility_id}"
      end
    end

    # Generate Oracle Health events for explicit facility IDs
    #
    # This method allows callers to specify facility IDs directly rather than
    # deriving them from the user object. Useful when facility context is known
    # from the operation being performed (e.g., prescription refill at a specific station).
    #
    # Unlike generate_events, this method does not check TRACKED_EVENTS since the caller
    # is explicitly requesting OH tracking by providing facility IDs.
    #
    # @param event_name [String] Name of the original event
    # @param event_facility_ids [Array<String>] Facility IDs associated with the event/operation,
    #   which will be checked against tracked OH facilities
    # @return [Array<String>] Array of OH event names to be logged for matching facilities
    def self.generate_events_for_facilities(event_name:, event_facility_ids:)
      matching_facilities = filter_tracked_facilities(event_facility_ids)
      matching_facilities.map do |facility_id|
        "#{event_name}_oh_site_#{facility_id}"
      end
    end

    # Filter provided facility IDs to only include tracked OH facilities
    #
    # @param facility_ids [Array<String>] Array of facility IDs to filter
    # @return [Array<String>] Array of matching facility IDs
    def self.filter_tracked_facilities(facility_ids)
      return [] if facility_ids.blank?

      # Normalize to strings for comparison
      normalized_ids = facility_ids.map(&:to_s)
      normalized_ids & TRACKED_FACILITY_IDS
    end

    # Get user's facilities that match tracked OH facilities
    #
    # @param user [User] the authenticated User object
    # @return [Array<String>] Array of matching facility IDs
    def self.get_user_tracked_facilities(user)
      user_facilities = user.vha_facility_ids || []
      user_facilities & TRACKED_FACILITY_IDS
    end

    private_class_method :get_user_tracked_facilities, :filter_tracked_facilities
  end
end
