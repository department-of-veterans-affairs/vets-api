# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    # Determines refillability for Oracle Health FHIR MedicationRequest resources
    # Implements gate-check logic for VA prescription refill eligibility
    #
    # This module is designed to be included in OracleHealthPrescriptionAdapter
    # and has dependencies on methods from the including class and other mixed-in modules:
    #
    # Required methods from including class (OracleHealthPrescriptionAdapter):
    # - extract_expiration_date(resource) - Extracts validityPeriod.end from resource
    #
    # Required methods from other modules (via include):
    # - categorize_medication(resource) - From OracleHealthCategorizer
    # - non_va_med?(resource) - From OracleHealthCategorizer
    # - medication_dispenses(resource) - From FhirHelpers
    # - find_most_recent_medication_dispense(contained) - From FhirHelpers
    # - log_invalid_expiration_date(resource, date) - From FhirHelpers
    module OracleHealthRefillHelper
      # Determines if a medication is refillable based on gate checks
      # A medication is refillable only if ALL gate conditions pass
      #
      # Gate 1: Not a non-VA medication
      # Gate 2: MedicationRequest.status == 'active'
      # Gate 3: Prescription not expired
      # Gate 4: Refills remaining > 0
      # Gate 5: At least one dispense exists
      # Gate 6: Most recent dispense is not in-progress
      # Gate 7: No pending refill request (refill_status != 'submitted')
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @param refill_status [String] Current refill status
      # @return [Boolean] true if refillable
      def refillable?(resource, refill_status)
        return false if non_va_med?(resource)
        return false unless resource['status'] == 'active'
        return false unless prescription_not_expired?(resource)
        return false unless extract_refill_remaining(resource).positive?
        return false if medication_dispenses(resource).empty?
        return false if most_recent_dispense_in_progress?(resource)
        return false if refill_status == 'submitted'

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
        return 0 if non_va_med?(resource)

        repeats_allowed = resource.dig('dispenseRequest', 'numberOfRepeatsAllowed') || 0
        dispenses_completed = medication_dispenses(resource).count { |d| d['status'] == 'completed' }

        remaining = repeats_allowed - [dispenses_completed - 1, 0].max
        remaining.positive? ? remaining : 0
      end

      # Checks if most recent MedicationDispense is in-progress
      # In-progress statuses: preparation, in-progress, on-hold
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] True if most recent dispense is in-progress
      def most_recent_dispense_in_progress?(resource)
        most_recent = find_most_recent_medication_dispense(resource)
        return false if most_recent.nil?

        %w[preparation in-progress on-hold].include?(most_recent['status'])
      end
    end
  end
end
