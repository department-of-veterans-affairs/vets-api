# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    # Helper mixin for Oracle Health (Cerner) medication refill logic.
    #
    # This module encapsulates common checks used to determine whether a
    # MedicationRequest resource is refillable (e.g., expiration, refill
    # counts, dispense status, and non-VA medication rules).
    #
    # Usage:
    #   - Include this module in a class that works with Oracle Health FHIR
    #     MedicationRequest resources.
    #   - The including class is expected to provide several helper methods
    #     used by this module (see below).
    #
    # Required methods on the including class:
    #   - #non_va_med?(resource) -> Boolean
    #       Determines whether the given MedicationRequest represents a
    #       non-VA medication (non-VA medications are never refillable).
    #   - #extract_expiration_date(resource) -> String, nil
    #       Returns the prescription expiration date string (or nil if none).
    #   - #find_most_recent_medication_dispense(contained_resources) -> Hash, nil
    #       Given the "contained" resources from a MedicationRequest, returns
    #       the most recent MedicationDispense resource, or nil if none.
    #   - #log_invalid_expiration_date(resource, expiration_date) -> void
    #       Logs or records details about an invalid/unparsable expiration date.
    #
    # Dependencies:
    #   - This module is intended to be used alongside other Oracle Health
    #     FHIR helpers, such as OracleHealthCategorizer and FhirHelpers, which
    #     may provide the required helper methods listed above.
    module OracleHealthRefillHelper
      # Determines if a medication is refillable based on gate checks
      def refillable?(resource, refill_status)
        return false if non_va_med?(resource) # Non-VA meds are never refillable
        return false unless resource['status'] == 'active' # must be active
        return false unless prescription_not_expired?(resource) # must not be expired
        return false unless extract_refill_remaining(resource).positive? # must have refills remaining
        return false if find_most_recent_medication_dispense(resource['contained']).nil? # must have dispenses availble
        return false if most_recent_dispense_in_progress?(resource) # must not have in-progress dispense
        return false if refill_status == 'submitted' # must not have a pending refill request

        true
      end

      # Checks if prescription expiration date is in the future
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if not expired
      def prescription_not_expired?(resource)
        expiration_date = extract_expiration_date(resource)
        return false unless expiration_date # No expiration date = not refillable for safety

        begin
          parsed_date = Time.zone.parse(expiration_date)
          return parsed_date&.> Time.zone.now if parsed_date

          # If we get here, parsing returned nil (invalid date)
          log_invalid_expiration_date(resource, expiration_date)
          false
        rescue ArgumentError
          log_invalid_expiration_date(resource, expiration_date)
          false
        end
      end

      # Calculates refills remaining for the medication
      # Non-VA medications always return 0 refills
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Integer] Number of refills remaining
      def extract_refill_remaining(resource)
        # non-va meds are never refillable
        return 0 if non_va_med?(resource)

        repeats_allowed = resource.dig('dispenseRequest', 'numberOfRepeatsAllowed') || 0
        # subtract dispenses in completed status, except for the first fill
        dispenses_completed = if resource['contained']
                                resource['contained'].count do |c|
                                  c['resourceType'] == 'MedicationDispense' && c['status'] == 'completed'
                                end
                              else
                                0
                              end
        remaining = repeats_allowed - [dispenses_completed - 1, 0].max
        remaining.positive? ? remaining : 0
      end

      # Checks if the most recent MedicationDispense has an in-progress status
      # In-progress statuses: preparation, in-progress, on-hold
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] True if most recent dispense is in-progress
      def most_recent_dispense_in_progress?(resource)
        most_recent_dispense = find_most_recent_medication_dispense(resource['contained'])
        return false if most_recent_dispense.nil?

        in_progress_statuses = %w[preparation in-progress on-hold]
        in_progress_statuses.include?(most_recent_dispense['status'])
      end
    end
  end
end
