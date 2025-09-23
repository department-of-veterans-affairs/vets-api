# frozen_string_literal: true

module UniqueUserEvents
  # Oracle Health specific functionality for unique user metrics
  #
  # This module handles the generation of Oracle Health site-specific events
  # based on user facility registrations and tracked events.
  module OracleHealth
    # Tracked facility IDs that should generate OH events
    TRACKED_FACILITY_IDS = %w[757 442].freeze

    # Events that should generate Oracle Health site-specific events
    # These must match events from
    # https://github.com/department-of-veterans-affairs/vets-website/blob/main/src/platform/mhv/unique_user_metrics/eventRegistry.js
    TRACKED_EVENTS = %w[
      mhv_sm_message_sent
      mhv_rx_refill_requested
      mhv_appointments_accessed
      mhv_mr_allergies_accessed
      mhv_mr_vaccines_accessed
      mhv_mr_labs_accessed
      mhv_mr_notes_accessed
      mhv_mr_vitals_accessed
      mhv_mr_conditions_accessed
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

    # Get user's facilities that match tracked OH facilities
    #
    # @param user [User] the authenticated User object
    # @return [Array<String>] Array of matching facility IDs
    def self.get_user_tracked_facilities(user)
      user_facilities = user.vha_facility_ids || []
      user_facilities & TRACKED_FACILITY_IDS
    end

    private_class_method :get_user_tracked_facilities
  end
end
