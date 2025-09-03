# frozen_string_literal: true

require_relative 'vista_prescription_adapter'
require_relative 'oracle_health_prescription_adapter'

module UnifiedHealthData
  module Adapters
    class PrescriptionsAdapter
      def initialize
        @vista_adapter = VistaPrescriptionAdapter.new
        @oracle_adapter = OracleHealthPrescriptionAdapter.new
      end

      def parse(body)
        return [] if body.nil?

        prescriptions = []

        # Parse VistA medications
        vista_medications = parse_vista_medications(body)
        prescriptions.concat(vista_medications) if vista_medications.present?

        # Parse Oracle Health medications
        oracle_medications = parse_oracle_medications(body)
        prescriptions.concat(oracle_medications) if oracle_medications.present?

        prescriptions
      end

      private

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
