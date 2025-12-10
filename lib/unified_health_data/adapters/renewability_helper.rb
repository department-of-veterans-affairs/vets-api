# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    # Helper methods for determining Oracle Health prescription renewability
    # See spec/support/vcr_cassettes/unified_health_data/# Oracle Health VA Dispensed Medications.md
    module RenewabilityHelper
      # Determines if an Oracle Health VA-dispensed medication is renewable.
      # A medication is renewable only if ALL gate conditions are met.
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if medication is renewable, false otherwise
      def extract_is_renewable(resource)
        # Gate 1: MedicationRequest.status must be 'active'
        return false unless resource['status'] == 'active'

        # Gate 2: Must be classified as VA Prescription or Clinic Administered Medication
        # NOT a Documented/Non-VA medication or unclassified
        return false unless renewable_medication_classification?(resource)

        # Gate 3: Must have at least one dispense
        return false unless dispenses?(resource)

        # Gate 4: Must have zero refills remaining
        return false if extract_refill_remaining(resource).positive?

        # Gate 5: No active processing (no in-progress/preparation dispense, no web/mobile refill request)
        return false if active_processing?(resource)

        # Gate 6: Must be within 120 days of validity period end
        return false unless within_renewal_window?(resource)

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

      # Gate 5: Checks if there is any active processing on the medication
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

      # Gate 6: Checks if the medication is within the 120-day renewal window
      # A medication is within the window if current_date - validity_period_end <= 120 days
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if within 120 days of validity period end
      def within_renewal_window?(resource)
        expiration_date = parse_expiration_date_utc(resource)
        return false if expiration_date.nil?

        # Allow renewal if within 120 days after expiration
        # (current_date - expiration_date) <= 120 days
        days_since_expiration = (Time.current.utc - expiration_date) / 1.day
        days_since_expiration <= 120
      end
    end
  end
end
