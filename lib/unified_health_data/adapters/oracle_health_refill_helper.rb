# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    module OracleHealthRefillHelper
      # Determines if a medication is refillable based on gate checks
      def refillable?(resource, refill_status)
        return false if non_va_med?(resource)
        return false unless resource['status'] == 'active'
        return false unless prescription_not_expired?(resource)
        return false unless extract_refill_remaining(resource).positive?
        return false if find_most_recent_medication_dispense(resource['contained']).nil?
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
