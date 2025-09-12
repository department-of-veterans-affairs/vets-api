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
                                                        is_trackable: extract_is_trackable(resource),
                                                        instructions: extract_instructions(resource),
                                                        facility_phone_number: extract_facility_phone_number(resource),
                                                        data_source_system: 'ORACLE_HEALTH',
                                                        ndc_number: extract_ndc_number(resource),
                                                        prescribed_date: resource['authoredOn'],
                                                        tracking_info: extract_tracking_info(resource),
                                                        prescription_source: 'UHD'
                                                      })
      end
      # rubocop:enable Metrics/MethodLength

      def extract_refill_status(resource)
        status = resource['status']
        case status
        when 'active' then 'active'
        when 'completed' then 'expired'
        when 'stopped', 'cancelled', 'entered-in-error' then 'discontinued'
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
        # Primary: dispenseRequest.performer
        performer_display = resource.dig('dispenseRequest', 'performer', 'display')
        return performer_display if performer_display

        # Fallback: check contained MedicationDispense for location
        if resource['contained']
          dispense = find_medication_dispense(resource['contained'])
          location = dispense&.dig('location', 'display')
          return location if location
        end

        # Final fallback: requester
        resource.dig('requester', 'display')
      end

      def extract_quantity(resource)
        # Primary: dispenseRequest.quantity.value
        quantity = resource.dig('dispenseRequest', 'quantity', 'value')
        return quantity if quantity

        # Fallback: check contained MedicationDispense
        if resource['contained']
          dispense = find_medication_dispense(resource['contained'])
          return dispense.dig('quantity', 'value') if dispense
        end

        nil
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
        # Check for contained MedicationDispense resources
        if resource['contained']
          dispense = find_medication_dispense(resource['contained'])
          return dispense['whenHandedOver'] if dispense&.dig('whenHandedOver')
        end

        # Fallback to initial fill date
        resource.dig('dispenseRequest', 'initialFill', 'date')
      end

      def extract_station_number(resource)
        resource.dig('dispenseRequest', 'performer', 'identifier', 'value')
      end

      def extract_is_refillable(resource)
        status = resource['status']
        refills_remaining = extract_refill_remaining(resource)

        # Only active prescriptions with remaining refills are refillable
        status == 'active' && refills_remaining.positive?
      end

      def extract_instructions(resource)
        dosage_instructions = resource['dosageInstruction'] || []
        return nil if dosage_instructions.empty?

        first_instruction = dosage_instructions.first

        # Use patientInstruction if available (more user-friendly)
        return first_instruction['patientInstruction'] if first_instruction['patientInstruction']

        # Otherwise use text
        return first_instruction['text'] if first_instruction['text']

        # Build from components
        build_instruction_text(first_instruction)
      end

      def extract_facility_phone_number(resource)
        # Try to extract from performer contact info if available
        performer = resource.dig('dispenseRequest', 'performer')
        return nil unless performer

        # This might be in an extension or contained Organization resource
        # For now, return nil as it's not typically in standard FHIR
        nil
      end

      def build_instruction_text(instruction)
        parts = []
        parts << instruction.dig('timing', 'code', 'text') if instruction.dig('timing', 'code', 'text')
        parts << instruction.dig('route', 'text') if instruction.dig('route', 'text')

        dose_and_rate = instruction.dig('doseAndRate', 0)
        if dose_and_rate
          dose_quantity = dose_and_rate.dig('doseQuantity', 'value')
          dose_unit = dose_and_rate.dig('doseQuantity', 'unit')
          parts << "#{dose_quantity} #{dose_unit}" if dose_quantity
        end

        parts.join(' ')
      end

      def find_medication_dispense(contained_resources)
        return nil unless contained_resources.is_a?(Array)

        contained_resources.find { |c| c['resourceType'] == 'MedicationDispense' }
      end

      def extract_is_trackable(resource)
        # Check if prescription has tracking information
        extract_tracking_info(resource).any?
      end

      def extract_ndc_number(resource)
        # Look for NDC in medication coding
        coding = resource.dig('medicationCodeableConcept', 'coding') || []
        ndc_coding = coding.find { |c| c['system']&.include?('ndc') || c['system']&.include?('NDC') }
        ndc_coding ? ndc_coding['code'] : nil
      end

      def extract_tracking_info(resource)
        tracking_info = []

        # Check for tracking info in contained MedicationDispense
        if resource['contained']
          dispense = find_medication_dispense(resource['contained'])
          if dispense
            # Look for tracking extension or identifier
            tracking_extension = find_tracking_extension(dispense)
            if tracking_extension
              tracking_info << extract_tracking_from_extension(tracking_extension)
            end

            # Look for tracking in identifiers
            tracking_identifier = find_tracking_identifier(dispense)
            if tracking_identifier
              tracking_info << extract_tracking_from_identifier(tracking_identifier)
            end
          end
        end

        # Look for tracking in extensions at the request level
        request_tracking = find_tracking_extension(resource)
        if request_tracking
          tracking_info << extract_tracking_from_extension(request_tracking)
        end

        tracking_info.compact
      end

      def find_tracking_extension(resource)
        extensions = resource['extension'] || []
        extensions.find { |ext| ext['url']&.include?('tracking') || ext['url']&.include?('shipment') }
      end

      def find_tracking_identifier(resource)
        identifiers = resource['identifier'] || []
        identifiers.find { |id| id['type']&.dig('text')&.downcase&.include?('tracking') }
      end

      def extract_tracking_from_extension(extension)
        return nil unless extension

        {
          'tracking_number' => extension.dig('valueString'),
          'shipper' => extension.dig('valueCodeableConcept', 'text')
        }.compact
      end

      def extract_tracking_from_identifier(identifier)
        return nil unless identifier

        {
          'tracking_number' => identifier['value'],
          'shipper' => identifier.dig('assigner', 'display')
        }.compact
      end
    end
  end
end
