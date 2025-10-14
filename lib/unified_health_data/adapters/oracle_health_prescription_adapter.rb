# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    class OracleHealthPrescriptionAdapter
      # Parses an Oracle Health FHIR MedicationRequest into a UnifiedHealthData::Prescription
      #
      # @param resource [Hash] FHIR MedicationRequest resource from Oracle Health
      # @return [UnifiedHealthData::Prescription, nil] Parsed prescription or nil if invalid
      def parse(resource)
        return nil if resource.nil? || resource['id'].nil?

        UnifiedHealthData::Prescription.new(build_prescription_attributes(resource))
      rescue => e
        Rails.logger.error("Error parsing Oracle Health prescription: #{e.message}")
        nil
      end

      private

      def build_prescription_attributes(resource)
        tracking_data = build_tracking_information(resource)

        build_core_attributes(resource)
          .merge(build_tracking_attributes(tracking_data))
          .merge(build_contact_and_source_attributes(resource))
      end

      def build_core_attributes(resource)
        {
          id: resource['id'],
          type: 'Prescription',
          refill_status: resource['status'],
          refill_submit_date: nil, # Not available in FHIR
          refill_date: extract_refill_date(resource),
          refill_remaining: extract_refill_remaining(resource),
          facility_name: extract_facility_name(resource),
          ordered_date: resource['authoredOn'],
          quantity: extract_quantity(resource),
          expiration_date: extract_expiration_date(resource),
          prescription_number: extract_prescription_number(resource),
          prescription_name: extract_prescription_name(resource),
          dispensed_date: nil, # Not available in FHIR
          station_number: extract_station_number(resource),
          is_refillable: extract_is_refillable(resource)
        }
      end

      def build_tracking_attributes(tracking_data)
        {
          is_trackable: tracking_data.any?,
          tracking: tracking_data
        }
      end

      def build_contact_and_source_attributes(resource)
        {
          instructions: extract_instructions(resource),
          facility_phone_number: extract_facility_phone_number(resource),
          prescription_source: extract_prescription_source(resource)
        }
      end

      def build_tracking_information(resource)
        contained_resources = resource['contained'] || []
        dispenses = contained_resources.select { |c| c['resourceType'] == 'MedicationDispense' }

        dispenses.filter_map do |dispense|
          extract_tracking_from_dispense(resource, dispense)
        end.compact
      end

      def extract_tracking_from_dispense(resource, dispense)
        identifiers = dispense['identifier'] || []

        tracking_number = find_identifier_value(identifiers, 'Tracking Number')
        return nil unless tracking_number # Only create tracking record if we have a tracking number

        prescription_number = find_identifier_value(identifiers, 'Prescription Number')
        carrier = find_identifier_value(identifiers, 'Carrier')
        shipped_date = find_identifier_value(identifiers, 'Shipped Date')

        {
          prescription_name: extract_prescription_name(resource),
          prescription_number: prescription_number || extract_prescription_number(resource),
          ndc_number: extract_ndc_number(dispense),
          prescription_id: resource['id'],
          tracking_number:,
          shipped_date:,
          carrier:,
          other_prescriptions: [] # TODO: Implement logic to find other prescriptions in this package
        }
      end

      def find_identifier_value(identifiers, type_text)
        identifier = identifiers.find { |id| id.dig('type', 'text') == type_text }
        identifier&.dig('value')
      end

      def extract_ndc_number(dispense)
        coding = dispense.dig('medicationCodeableConcept', 'coding') || []
        ndc_coding = coding.find { |c| c['system'] == 'http://hl7.org/fhir/sid/ndc' }
        ndc_coding&.dig('code')
      end

      def extract_refill_date(resource)
        dispense = find_most_recent_medication_dispense(resource['contained'])
        return dispense['whenHandedOver'] if dispense&.dig('whenHandedOver')

        nil
      end

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

      def extract_facility_name(resource)
        # Primary: dispenseRequest.performer
        performer_display = resource.dig('dispenseRequest', 'performer', 'display')
        return performer_display if performer_display

        # Fallback: check contained Encounter for location
        if resource['contained']
          encounter = resource['contained'].find { |c| c['resourceType'] == 'Encounter' }
          if encounter
            location_display = encounter.dig('location', 0, 'location', 'display')
            return location_display if location_display
          end
        end

        nil
      end

      def extract_quantity(resource)
        # Primary: dispenseRequest.quantity.value
        quantity = resource.dig('dispenseRequest', 'quantity', 'value')
        return quantity if quantity

        # Fallback: check contained MedicationDispense
        dispense = find_most_recent_medication_dispense(resource['contained'])
        return dispense.dig('quantity', 'value') if dispense

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

      def extract_station_number(resource)
        dispense = find_most_recent_medication_dispense(resource['contained'])
        raw_station_number = dispense&.dig('location', 'display')
        return nil unless raw_station_number

        # Extract first 3 digits from format like "556-RX-MAIN-OP"
        match = raw_station_number.match(/^(\d{3})/)
        if match
          match[1]
        else
          Rails.logger.warn("Unable to extract 3-digit station number from: #{raw_station_number}")
          raw_station_number
        end
      end

      def extract_is_refillable(resource)
        refillable = true

        # non VA meds are never refillable
        refillable = false if non_va_med?(resource)
        # must be active
        refillable = false unless resource['status'] == 'active'
        # must not be expired
        refillable = false unless prescription_not_expired?(resource)
        # must have refills remaining
        refillable = false unless extract_refill_remaining(resource).positive?
        # must have at least one dispense record
        refillable = false if find_most_recent_medication_dispense(resource['contained']).nil?

        refillable
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

      def extract_prescription_source(resource)
        non_va_med?(resource) ? 'NV' : ''
      end

      def non_va_med?(resource)
        resource['reportedBoolean'] == true
      end

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

      def log_invalid_expiration_date(resource, expiration_date)
        Rails.logger.warn("Invalid expiration date for prescription #{resource['id']}: #{expiration_date}")
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

      def find_most_recent_medication_dispense(contained_resources)
        return nil unless contained_resources.is_a?(Array)

        dispenses = contained_resources.select { |c| c['resourceType'] == 'MedicationDispense' }
        return nil if dispenses.empty?

        # Sort by whenHandedOver date, most recent first
        dispenses.max_by do |dispense|
          when_handed_over = dispense['whenHandedOver']
          when_handed_over ? Time.zone.parse(when_handed_over) : Time.zone.at(0)
        end
      end
    end
  end
end
