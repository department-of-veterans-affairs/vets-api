# frozen_string_literal: true

# ⚠️  WARNING: DATABASE SIZE IMPACT ⚠️
#
# BEFORE ADDING NEW EVENTS TO THIS REGISTRY:
#
# 1. Each new event type creates a new record for EVERY user who triggers it
# 2. With millions of VA users, each event can result in millions of database records
# 3. Consider the long-term storage implications before adding events
# 4. Discuss with the backend team and database administrators
# 5. Only add events that provide significant analytical value and use other
#    methods to track the same information (e.g., Google Analytics)
#
# EVENT NAMING CONVENTION:
# - Use pattern: feature_action_accessed (e.g., "mhv_landing_page_accessed")
# - Maximum 50 characters per event name
# - Be descriptive but concise
# - Use lowercase with underscores
#
# ⚠️  THINK TWICE BEFORE ADDING NEW EVENTS ⚠️

module UniqueUserEvents
  ##
  # Centralized registry of all unique user metric event identifiers.
  # This forces developers to come to one place to add new events and
  # see the database size warning above.
  #
  # All event logging must use events from this registry to prevent
  # uncontrolled database growth.
  module EventRegistry
    # Secure Messaging Events
    SECURE_MESSAGING_MESSAGE_SENT = 'mhv_sm_message_sent'
    SECURE_MESSAGING_INBOX_ACCESSED = 'mhv_sm_inbox_accessed'

    # Prescriptions Events
    PRESCRIPTIONS_ACCESSED = 'mhv_rx_accessed'
    PRESCRIPTIONS_REFILL_REQUESTED = 'mhv_rx_refill_requested'

    # Medical Records Events
    MEDICAL_RECORDS_ACCESSED = 'mhv_mr_accessed'
    MEDICAL_RECORDS_LABS_ACCESSED = 'mhv_mr_labs_accessed'
    MEDICAL_RECORDS_VITALS_ACCESSED = 'mhv_mr_vitals_accessed'
    MEDICAL_RECORDS_VACCINES_ACCESSED = 'mhv_mr_vaccines_accessed'
    MEDICAL_RECORDS_ALLERGIES_ACCESSED = 'mhv_mr_allergies_accessed'
    MEDICAL_RECORDS_CONDITIONS_ACCESSED = 'mhv_mr_conditions_accessed'
    MEDICAL_RECORDS_NOTES_ACCESSED = 'mhv_mr_notes_accessed'

    # Appointments Events
    APPOINTMENTS_ACCESSED = 'mhv_appointments_accessed'

    # Frozen set of all valid event names for validation
    # This is automatically generated from all constants defined above
    VALID_EVENTS = constants(false).map { |const| const_get(const) }.freeze

    ##
    # Validates that an event name is in the registry.
    #
    # @param event_name [String] Name of the event to validate
    # @return [Boolean] true if valid, false otherwise
    #
    # @example
    #   EventRegistry.valid_event?('mhv_sm_message_sent') # => true
    #   EventRegistry.valid_event?('random_event') # => false
    def self.valid_event?(event_name)
      VALID_EVENTS.include?(event_name)
    end

    ##
    # Validates that an event name is in the registry, raising an error if invalid.
    #
    # @param event_name [String] Name of the event to validate
    # @raise [ArgumentError] if event name is not in the registry
    #
    # @example
    #   EventRegistry.validate_event!('mhv_sm_message_sent') # => nil
    #   EventRegistry.validate_event!('random_event') # => raises ArgumentError
    def self.validate_event!(event_name)
      return if valid_event?(event_name)

      raise ArgumentError,
            "Invalid event name: '#{event_name}'. Must be one of: #{VALID_EVENTS.join(', ')}"
    end
  end
end
