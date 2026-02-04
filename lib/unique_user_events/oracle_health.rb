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
    #    - Uses the user's VHA facility registrations
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

      # Normalize to strings for comparison
      normalized_ids = facility_ids.map(&:to_s)

      # Get user's Cerner facility IDs (actual OH facilities for this user)
      cerner_ids = (user.cerner_facility_ids || []).map(&:to_s)

      # Facility must be:
      # 1. In the provided facility_ids
      # 2. In the tracked facility list (controlled rollout)
      # 3. An actual OH facility for this user (cerner_facility_ids)
      normalized_ids & TRACKED_FACILITY_IDS & cerner_ids
    end

    # Get user's facilities that match tracked OH facilities
    #
    # @param user [User] the authenticated User object
    # @return [Array<String>] Array of matching facility IDs
    def self.get_user_tracked_facilities(user)
      user_facilities = user.vha_facility_ids || []
      user_facilities & TRACKED_FACILITY_IDS
    end

    private_class_method :get_user_tracked_facilities, :filter_tracked_oh_facilities
  end
end
