# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    # Helper methods for determining Oracle Health prescription renewability.
    #
    # @note This module is designed to be included in OracleHealthPrescriptionAdapter.
    #   It depends on the following methods from the including class:
    #   - extract_category(resource) - Returns Array<String> of category codes
    #   - extract_refill_remaining(resource) - Returns Integer of remaining refills
    #   - parse_expiration_date_utc(resource) - Returns Time or nil for expiration date
    module RenewabilityHelper
      # Determines if an Oracle Health VA-dispensed medication is renewable.
      # A medication is renewable only if ALL gate conditions are met.
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if medication is renewable, false otherwise
      def extract_is_renewable(resource)
        return false if resource.nil? || !resource.is_a?(Hash)

        # Gate 1: MedicationRequest.status must be 'active'
        return false unless resource['status'] == 'active'

        # Gate 2: Must be classified as VA Prescription or Clinic Administered Medication
        # NOT a Documented/Non-VA medication or unclassified
        return false unless renewable_medication_classification?(resource)

        # Gate 3: Must have at least one dispense
        return false unless dispenses?(resource)

        # Gate 4: Validity period end date must exist
        return false unless validity_period_end_exists?(resource)

        # Gate 5: Must be within 120 days of validity period end
        return false unless within_renewal_window?(resource)

        # Gate 6: Refills remaining must be zero OR prescription is expired
        # If prescription is expired, renewal is appropriate even with refills remaining
        # because refills cannot be processed on an expired prescription
        return false unless refills_exhausted_or_expired?(resource)

        # Gate 7: No active processing (no in-progress/preparation dispense, no web/mobile refill request)
        return false if active_processing?(resource)

        true
      end

      private

      # Gate 2: Classifies medication and checks if eligible for renewal
      # Classification is determined by reportedBoolean, intent, and category values.
      #
      # Renewable Classifications:
      # - VA Prescription: reportedBoolean=false, intent='order', category includes BOTH community AND discharge
      # - Clinic Administered: reportedBoolean=false, intent='order', category is outpatient
      #
      # Non-Renewable Classifications:
      # - Documented/Non-VA: reportedBoolean=true, intent='plan', category includes community AND patient-specified
      # - Any other combination (Unclassified)
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if classified as VA Prescription or Clinic Administered
      def renewable_medication_classification?(resource)
        reported_boolean = resource['reportedBoolean']
        intent = resource['intent']
        categories = extract_category(resource)

        # VA Prescription: reportedBoolean=false, intent='order', both community AND discharge
        return true if va_prescription?(reported_boolean, intent, categories)

        # Clinic Administered: reportedBoolean=false, intent='order', outpatient only
        return true if clinic_administered?(reported_boolean, intent, categories)

        # All other combinations are not renewable (Documented/Non-VA or Unclassified)
        false
      end

      # Checks if medication is classified as a VA Prescription
      # VA Prescription: reportedBoolean=false, intent='order', category is EXACTLY community AND discharge (no others)
      #
      # @param reported_boolean [Boolean] MedicationRequest.reportedBoolean value
      # @param intent [String] MedicationRequest.intent value
      # @param categories [Array<String>] Extracted category codes
      # @return [Boolean] true if VA Prescription classification
      def va_prescription?(reported_boolean, intent, categories)
        reported_boolean == false &&
          intent == 'order' &&
          categories.sort == %w[community discharge]
      end

      # Checks if medication is classified as a Clinic Administered Medication
      # Clinic Administered: reportedBoolean=false, intent='order', category is ONLY outpatient
      #
      # @param reported_boolean [Boolean] MedicationRequest.reportedBoolean value
      # @param intent [String] MedicationRequest.intent value
      # @param categories [Array<String>] Extracted category codes
      # @return [Boolean] true if Clinic Administered classification
      def clinic_administered?(reported_boolean, intent, categories)
        reported_boolean == false &&
          intent == 'order' &&
          categories == ['outpatient']
      end

      # Gate 3: Checks if the MedicationRequest has any dispenses
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if at least one dispense exists
      def dispenses?(resource)
        contained_resources = resource['contained'] || []
        contained_resources.any? { |c| c['resourceType'] == 'MedicationDispense' }
      end

      # Gate 4: Checks if the validity period end date exists
      # A prescription without a validity period end date cannot be evaluated for renewal
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if validity period end date exists
      def validity_period_end_exists?(resource)
        resource.dig('dispenseRequest', 'validityPeriod', 'end').present?
      end

      # Gate 6: Checks if refills are exhausted OR prescription is expired
      # A prescription is eligible for renewal if:
      # - Refills remaining == 0 AND prescription is NOT expired, OR
      # - Prescription IS expired (regardless of refills remaining)
      #
      # Rationale: If refills are available AND prescription is still valid,
      # patient should use the refill process. However, if expired, renewal
      # is the appropriate path since refills cannot be processed on an expired prescription.
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if eligible based on refills/expiration logic
      def refills_exhausted_or_expired?(resource)
        refills_remaining = extract_refill_remaining(resource)
        expired = prescription_expired?(resource)

        # Expired prescriptions are always eligible (within the 120-day window checked in Gate 5)
        return true if expired

        # Non-expired prescriptions must have zero refills remaining
        refills_remaining.zero?
      end

      # Checks if the prescription's validity period has ended
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if validity period end date is in the past
      def prescription_expired?(resource)
        expiration_date = parse_expiration_date_utc(resource)
        return false if expiration_date.nil?

        expiration_date < Time.current.utc
      end

      # Gate 7: Checks if there is any active processing on the medication
      # Active processing includes:
      # - A refill requested via web or mobile
      # - Any dispense with status 'in-progress' or 'preparation'
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if any active processing is detected
      def active_processing?(resource)
        # Check for web/mobile refill request
        return true if refill_requested_via_web_or_mobile?(resource)

        # Check for in-progress or preparation dispenses
        contained_resources = resource['contained'] || []
        dispenses = contained_resources.select { |c| c['resourceType'] == 'MedicationDispense' }

        dispenses.any? { |d| %w[in-progress preparation].include?(d['status']) }
      end

      # Checks if a refill has been requested via web or mobile
      # This is determined by looking for specific extensions or identifiers
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if a web/mobile refill request is pending
      def refill_requested_via_web_or_mobile?(resource)
        # Check extensions for refill request indicator
        extensions = resource['extension'] || []
        extensions.any? do |ext|
          ext['url']&.include?('refill-request') && ext['valueBoolean'] == true
        end
      end

      # Gate 5: Checks if the medication is within the 120-day renewal window
      # A prescription is within the renewal window if:
      # - The validity period has not yet ended (prescription is not expired), OR
      # - The validity period ended within the last 120 days
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if within renewal window
      def within_renewal_window?(resource)
        expiration_date = parse_expiration_date_utc(resource)
        return false if expiration_date.nil?

        # Allow renewal if:
        # 1. Prescription is not yet expired (expiration_date is in the future), OR
        # 2. Prescription expired within the last 120 days
        days_since_expiration = (Time.current.utc - expiration_date) / 1.day
        days_since_expiration <= 120
      end
    end
  end
end
