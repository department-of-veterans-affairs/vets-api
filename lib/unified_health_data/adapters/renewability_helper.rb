# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    # Helper methods for determining Oracle Health prescription renewability
    # See docs/oracle_health_renewability_spec.md for full specification
    module RenewabilityHelper
      # Determines if an Oracle Health VA-dispensed medication is renewable.
      # A medication is renewable only if ALL gate conditions are met.
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if medication is renewable, false otherwise
      def extract_is_renewable(resource)
        # Gate 1: MedicationRequest.status must be 'active'
        return false unless resource['status'] == 'active'

        # Gate 2: Must NOT be a documented/Non-VA medication
        return false if non_va_med?(resource)

        # Gate 3: Category must be outpatient, community, or discharge
        return false unless renewable_category?(resource)

        # Gate 4: Must have at least one dispense
        return false unless dispenses?(resource)

        # Gate 5: Must have zero refills remaining
        return false if extract_refill_remaining(resource).positive?

        # Gate 6: No active processing (no in-progress/preparation dispense, no web/mobile refill request)
        return false if active_processing?(resource)

        # Gate 7: Must be within 120 days of validity period end
        return false unless within_renewal_window?(resource)

        true
      end

      private

      # Gate 3: Checks if the MedicationRequest category is eligible for renewal
      # Only outpatient, community, and discharge categories are renewable
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if category is renewable
      def renewable_category?(resource)
        valid_categories = %w[outpatient community discharge]
        categories = extract_category(resource)
        return false if categories.empty?

        categories.any? { |category| valid_categories.include?(category) }
      end

      # Gate 4: Checks if the MedicationRequest has any dispenses
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] true if at least one dispense exists
      def dispenses?(resource)
        contained_resources = resource['contained'] || []
        contained_resources.any? { |c| c['resourceType'] == 'MedicationDispense' }
      end

      # Gate 6: Checks if there is any active processing on the medication
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

      # Gate 7: Checks if the medication is within the 120-day renewal window
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
