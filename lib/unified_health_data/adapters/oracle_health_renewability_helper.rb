# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    # Determines Oracle Health prescription renewability using gate-check logic.
    #
    # @note Designed to be included in OracleHealthPrescriptionAdapter.
    #   Requires these methods from the including class:
    #   - extract_refill_remaining(resource) - Returns Integer of remaining refills
    #   - parse_expiration_date_utc(resource) - Returns Time or nil for expiration date
    #
    #   Requires these methods from other modules (via include):
    #   - categorize_medication(resource) - From OracleHealthCategorizer
    module OracleHealthRenewabilityHelper
      # Determines if a medication is renewable.
      # All gate conditions must pass for renewal eligibility.
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if renewable
      def renewable?(resource)
        return false if resource.nil? || !resource.is_a?(Hash)

        # This order must be preserved for short-circuit efficiency
        return false unless resource['status'] == 'active' # Must be active
        return false unless renewable_category?(resource) # Must be VA Prescription or Clinic Administered
        return false unless dispenses?(resource) # Must have at least one dispense
        return false unless validity_period_end_exists?(resource) # Must have validity period end date
        return false unless within_renewal_window?(resource) # Must be within 120 days of validity period end
        return false unless refills_exhausted_or_expired?(resource) # Must have refills exhausted or be expired
        # Must not have active processing (refill request or in-progress dispense)
        return false if active_processing?(resource)

        true
      end

      private

      # Checks if medication category is renewable
      # Only VA Prescription and Clinic Administered are renewable
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if renewable category
      def renewable_category?(resource)
        category = categorize_medication(resource)
        %i[va_prescription clinic_administered].include?(category)
      end

      # Checks if medication has any dispenses
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if at least one dispense exists
      def dispenses?(resource)
        medication_dispenses(resource).any?
      end

      # Checks if validity period end date exists
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if validity period end exists
      def validity_period_end_exists?(resource)
        resource.dig('dispenseRequest', 'validityPeriod', 'end').present?
      end

      # Checks if within 120-day renewal window from expiration
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if within renewal window
      def within_renewal_window?(resource)
        expiration_date = parse_expiration_date_utc(resource)
        return false if expiration_date.nil?

        days_since_expiration = (Time.current.utc - expiration_date) / 1.day
        days_since_expiration <= 120
      end

      # Checks if refills exhausted or prescription expired
      # Expired prescriptions are always eligible (within 120-day window).
      # Non-expired prescriptions must have zero refills remaining.
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if eligible for renewal
      def refills_exhausted_or_expired?(resource)
        refills_remaining = extract_refill_remaining(resource)
        expired = prescription_expired?(resource)

        expired || refills_remaining.zero?
      end

      # Checks if prescription validity period has ended
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if expired
      def prescription_expired?(resource)
        expiration_date = parse_expiration_date_utc(resource)
        return false if expiration_date.nil?

        expiration_date < Time.current.utc
      end

      # Checks for active processing (web/mobile refill or in-progress dispense)
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if active processing detected
      def active_processing?(resource)
        return true if refill_requested_via_web_or_mobile?(resource)

        medication_dispenses(resource).any? do |dispense|
          %w[in-progress preparation].include?(dispense['status'])
        end
      end

      def medication_dispenses(resource)
        (resource['contained'] || []).select do |contained_resource|
          contained_resource['resourceType'] == 'MedicationDispense'
        end
      end

      # Checks for pending web/mobile refill request
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if refill requested via web/mobile
      def refill_requested_via_web_or_mobile?(resource)
        extensions = resource['extension'] || []
        extensions.any? do |ext|
          ext['url']&.include?('refill-request') && ext['valueBoolean'] == true
        end
      end
    end
  end
end
