# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    class OracleHealthPrescriptionAdapter
      def parse(resource)
        return nil if resource.nil? || resource['id'].nil?

        attributes = build_prescription_attributes(resource)
        UnifiedHealthData::Prescription.new({
                                              id: resource['id'],
                                              type: 'Prescription',
                                              attributes:
                                            })
      rescue => e
        Rails.logger.error("Error parsing Oracle Health prescription: #{e.message}")
        nil
      end

      private

      # rubocop:disable Metrics/MethodLength
      def build_prescription_attributes(resource)
        UnifiedHealthData::PrescriptionAttributes.new({
                                                        refill_status: extract_refill_status(resource),
                                                        refill_submit_date: nil, # Not available in FHIR
                                                        refill_date: extract_refill_date(resource),
                                                        refill_remaining:
                                                          extract_refill_remaining(resource),
                                                        facility_name: extract_facility_name(resource),
                                                        ordered_date: resource['authoredOn'],
                                                        quantity: extract_quantity(resource),
                                                        expiration_date: extract_expiration_date(resource),
                                                        prescription_number:
                                                          extract_prescription_number(resource),
                                                        prescription_name:
                                                          extract_prescription_name(resource),
                                                        dispensed_date: extract_dispensed_date(resource),
                                                        station_number: extract_station_number(resource),
                                                        is_refillable: extract_is_refillable(resource),
                                                        is_trackable: false, # Default for Oracle Health
                                                        instructions: extract_instructions(resource),
                                                        facility_phone_number: nil, # Not typically in FHIR
                                                        data_source_system: 'ORACLE_HEALTH'
                                                      })
      end
      # rubocop:enable Metrics/MethodLength

      def extract_refill_status(resource)
        status = resource['status']
        case status
        when 'active' then 'active'
        when 'completed' then 'expired'
        when 'stopped', 'cancelled' then 'discontinued'
        else status
        end
      end

      def extract_refill_date(resource)
        resource.dig('dispenseRequest', 'validityPeriod', 'start')
      end

      def extract_refill_remaining(resource)
        resource.dig('dispenseRequest', 'numberOfRepeatsAllowed') || 0
      end

      def extract_facility_name(resource)
        resource.dig('dispenseRequest', 'performer', 'display')
      end

      def extract_quantity(resource)
        resource.dig('dispenseRequest', 'quantity', 'value')
      end

      def extract_expiration_date(resource)
        resource.dig('dispenseRequest', 'validityPeriod', 'end')
      end

      def extract_prescription_number(resource)
        # Look for identifier with prescription number
        identifiers = resource['identifier'] || []
        prescription_id = identifiers.find { |id| id['system']&.include?('prescription') }
        prescription_id ? prescription_id['value'] : resource['id']
      end

      def extract_prescription_name(resource)
        resource.dig('medicationCodeableConcept', 'text') ||
          resource.dig('medicationReference', 'display')
      end

      def extract_dispensed_date(resource)
        resource.dig('dispenseRequest', 'initialFill', 'date')
      end

      def extract_station_number(resource)
        resource.dig('dispenseRequest', 'performer', 'identifier', 'value')
      end

      def extract_is_refillable(resource)
        status = resource['status']
        refills_remaining = extract_refill_remaining(resource)
        status == 'active' && refills_remaining.positive?
      end

      def extract_instructions(resource)
        dosage_instructions = resource['dosageInstruction'] || []
        return nil if dosage_instructions.empty?

        first_instruction = dosage_instructions.first
        first_instruction['text'] || build_instruction_text(first_instruction)
      end

      def build_instruction_text(instruction)
        parts = []
        parts << instruction.dig('timing', 'code', 'text') if instruction.dig('timing', 'code', 'text')
        parts << instruction.dig('route', 'text') if instruction.dig('route', 'text')
        parts << instruction.dig('doseAndRate', 0, 'doseQuantity', 'value') if instruction.dig('doseAndRate', 0,
                                                                                               'doseQuantity', 'value')
        parts.join(' ')
      end
    end
  end
end
