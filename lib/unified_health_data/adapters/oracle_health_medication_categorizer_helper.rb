# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    # Medication categorization helpers for FHIR MedicationRequest resources
    # Implements Oracle Health specification for medication type determination
    module OracleHealthMedicationCategorizerHelper
      # Extract category codes from FHIR MedicationRequest
      # Returns normalized (lowercase, sorted) codes for consistent comparison
      # @see https://build.fhir.org/valueset-medicationrequest-admin-location.html
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Array<String>] Normalized category codes (e.g., ['community', 'discharge'])
      def extract_category(resource)
        categories = resource['category'] || []
        return [] if categories.empty?

        # Category is an array of CodeableConcept objects
        # We collect all codes from all categories
        codes = []
        categories.each do |category|
          codings = category['coding'] || []
          codings.each do |coding|
            # Collect the code value if found (e.g., 'inpatient', 'outpatient', 'community')
            codes << coding['code'] if coding['code'].present?
          end
        end

        codes.map(&:downcase).sort
      end

      # Categorizes medication based on Oracle Health specification
      # Uses reportedBoolean, intent, and category fields to determine medication type
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Symbol] One of the available categories
      # @see https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/digital-health-modernization/mhv-to-va.gov/medications/requirements/oracle_health_categorization_spec.md
      def categorize_medication(resource)
        reported_boolean = resource['reportedBoolean']
        intent = resource['intent']
        categories = extract_category(resource)

        case categories
        when %w[community discharge]
          reported_boolean == false && intent == 'order' ? :va_prescription : :uncategorized
        when %w[community patientspecified]
          reported_boolean == true && intent == 'plan' ? :documented_non_va : :uncategorized
        when ['outpatient']
          reported_boolean == false && intent == 'order' ? :clinic_administered : :uncategorized
        when ['charge-only']
          :pharmacy_charges
        when ['inpatient']
          :inpatient
        else
          :uncategorized
        end
      end

      def log_uncategorized_medication(resource)
        return unless Flipper.enabled?(:mhv_medications_v2_status_mapping)

        Rails.logger.warn(
          message: 'Oracle Health medication uncategorized',
          prescription_id_suffix: resource['id']&.to_s&.last(3) || 'unknown',
          reported_boolean: resource['reportedBoolean'],
          intent: resource['intent'],
          category_codes: extract_category(resource),
          service: 'unified_health_data'
        )
      end
    end
  end
end
