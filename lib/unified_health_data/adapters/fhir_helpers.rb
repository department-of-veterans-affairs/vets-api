# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    # Generic FHIR resource parsing and utility methods
    # Shared across different FHIR adapters (MedicationRequest, etc.)
    module FhirHelpers
      # Parses a date string or returns epoch if invalid/missing
      #
      # @param date_string [String, nil] Date string to parse
      # @return [Time] Parsed time or epoch
      def parse_date_or_epoch(date_string)
        return Time.zone.at(0) unless date_string

        parsed_time = Time.zone.parse(date_string)
        parsed_time || Time.zone.at(0)
      rescue ArgumentError, TypeError
        Time.zone.at(0)
      end

      # Calculates days since a given date
      #
      # @param date_string [String] ISO 8601 date string
      # @return [Integer, nil] Days since the date or nil if invalid
      def days_since(date_string)
        return nil unless date_string

        submit_time = Time.zone.parse(date_string)
        return nil unless submit_time

        days = ((Time.zone.now - submit_time) / 1.day).floor
        days >= 0 ? days : nil
      rescue ArgumentError, TypeError
        nil
      end

      # Finds a FHIR identifier value by type text
      #
      # @param identifiers [Array<Hash>] Array of FHIR identifier objects
      # @param type_text [String] The type.text value to search for
      # @return [String, nil] The identifier value or nil if not found
      def find_identifier_value(identifiers, type_text)
        identifier = identifiers.find { |id| id.dig('type', 'text') == type_text }
        identifier&.dig('value')
      end

      # Extracts NDC (National Drug Code) from FHIR MedicationDispense
      #
      # @param dispense [Hash] FHIR MedicationDispense resource
      # @return [String, nil] NDC code or nil if not found
      def extract_ndc_number(dispense)
        coding = dispense.dig('medicationCodeableConcept', 'coding') || []
        ndc_coding = coding.find { |c| c['system'] == 'http://hl7.org/fhir/sid/ndc' }
        ndc_coding&.dig('code')
      end

      # Finds the most recent MedicationDispense from contained resources
      # Sorted by whenHandedOver date
      #
      # @param contained_resources [Array<Hash>] Array of FHIR contained resources
      # @return [Hash, nil] Most recent MedicationDispense or nil if none found
      def find_most_recent_medication_dispense(contained_resources)
        return nil unless contained_resources.is_a?(Array)

        dispenses = contained_resources.select { |c| c['resourceType'] == 'MedicationDispense' }
        return nil if dispenses.empty?

        # Sort by whenHandedOver date, most recent first
        dispenses.max_by do |dispense|
          when_handed_over = dispense['whenHandedOver']
          if when_handed_over
            begin
              Time.zone.parse(when_handed_over) || Time.zone.at(0)
            rescue ArgumentError, TypeError
              Time.zone.at(0)
            end
          else
            Time.zone.at(0)
          end
        end
      end

      # Builds instruction text from FHIR dosageInstruction components
      #
      # @param instruction [Hash] FHIR dosageInstruction object
      # @return [String] Formatted instruction text
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

      # Checks if MedicationRequest is a non-VA medication
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] True if non-VA medication
      def non_va_med?(resource)
        resource['reportedBoolean'] == true
      end

      # Logs warning for invalid expiration date
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @param expiration_date [String] Invalid expiration date string
      def log_invalid_expiration_date(resource, expiration_date)
        Rails.logger.warn("Invalid expiration date for prescription #{resource['id']}: #{expiration_date}")
      end

      # Extracts SIG (dosage instructions) from FHIR MedicationDispense
      # Concatenates all dosageInstruction texts
      #
      # @param dispense [Hash] FHIR MedicationDispense resource
      # @return [String, nil] Concatenated dosage instructions or nil if none
      def extract_sig_from_dispense(dispense)
        dosage_instructions = dispense['dosageInstruction'] || []
        return nil if dosage_instructions.empty?

        # Concatenate all dosage instruction texts
        texts = dosage_instructions.filter_map do |instruction|
          instruction['text'] if instruction.is_a?(Hash)
        end

        texts.empty? ? nil : texts.join(' ')
      end
    end
  end
end
