# frozen_string_literal: true

require_relative 'vista_prescription_adapter'
require_relative 'oracle_health_prescription_adapter'

module UnifiedHealthData
  module Adapters
    class PrescriptionsAdapter
      def initialize(current_user = nil)
        @vista_adapter = VistaPrescriptionAdapter.new
        @oracle_adapter = OracleHealthPrescriptionAdapter.new
        @current_user = current_user
      end

      def parse(body, current_only: false)
        return [] if body.nil?

        prescriptions = []

        # Parse VistA medications
        vista_medications = parse_vista_medications(body)
        prescriptions.concat(vista_medications) if vista_medications.present?

        # Parse Oracle Health medications
        oracle_medications = parse_oracle_medications(body)
        prescriptions.concat(oracle_medications) if oracle_medications.present?

        # Exclude certain prescriptions based on business rules
        prescriptions.reject! { |prescription| should_exclude_prescription?(prescription) }

        # Apply current filtering if requested
        prescriptions = apply_current_filtering(prescriptions) if current_only

        prescriptions
      end

      private

      def apply_current_filtering(prescriptions)
        filtered = prescriptions.reject { |prescription| prescription_not_current?(prescription) }

        Rails.logger.info(
          message: 'Applied current filtering to prescriptions',
          original_count: prescriptions.size,
          filtered_count: filtered.size,
          excluded_count: prescriptions.size - filtered.size
        )

        filtered
      end

      def prescription_not_current?(prescription)
        # Exclude discontinued/expired medications that are older than 180 days
        if %w[discontinued expired].include?(prescription.refill_status) &&
           prescription.expiration_date.present?
          begin
            expiration_date = Date.parse(prescription.expiration_date)
            return true if expiration_date < 180.days.ago
          rescue Date::Error, TypeError
            # If date parsing fails, don't exclude based on date
            # Only log last 4 digits of prescription ID for privacy
            rx_suffix = prescription.id.to_s.last(4)
            Rails.logger.warn("Invalid expiration date for rx ending in #{rx_suffix}: #{prescription.expiration_date}")
          end
        end

        false
      end

      def should_exclude_prescription?(prescription)
        # Mirror logic from Mobile::V0::PrescriptionsController#resource_data_modifications

        # Exclude Partial Fill (PF) and Pending Prescriptions (PD)
        display_pending_meds = Flipper.enabled?(:mhv_medications_display_pending_meds, @current_user)
        if display_pending_meds
          return true if prescription.prescription_source == 'PF'
        elsif %w[PF PD].include?(prescription.prescription_source)
          # TODO: remove this line when PF and PD are allowed on the app
          return true
        end

        false
      end

      def parse_vista_medications(body)
        vista_data = body['vista']
        return [] unless vista_data && vista_data['medicationList']

        medications = vista_data.dig('medicationList', 'medication')
        return [] unless medications.is_a?(Array)

        medications.map { |med| @vista_adapter.parse(med) }.compact
      end

      def parse_oracle_medications(body)
        oracle_data = body['oracle-health']
        return [] unless oracle_data && oracle_data['entry']

        entries = oracle_data['entry']
        return [] unless entries.is_a?(Array)

        # Filter for MedicationRequest resources
        medication_requests = entries.select do |entry|
          entry.dig('resource', 'resourceType') == 'MedicationRequest'
        end

        medication_requests.map { |entry| @oracle_adapter.parse(entry['resource']) }.compact
      end
    end
  end
end
