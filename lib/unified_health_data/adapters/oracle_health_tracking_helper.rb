# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    # Helper module for extracting tracking information from Oracle Health FHIR MedicationRequest resources
    # Supports both extension-based (new format) and identifier-based (legacy format) tracking data
    module OracleHealthTrackingHelper
      # Builds tracking information from MedicationRequest dispenses
      # Tries extension-based format first, falls back to identifier-based format
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Array<Hash>] Array of tracking information hashes
      def build_tracking_information(resource)
        contained_resources = resource['contained'] || []
        dispenses = contained_resources.select { |c| c['resourceType'] == 'MedicationDispense' }

        # Try extension-based tracking first (new format)
        tracking_from_extensions = dispenses.filter_map do |dispense|
          build_tracking_from_extensions(resource, dispense)
        end

        return tracking_from_extensions if tracking_from_extensions.any?

        # Fallback to identifier-based tracking (legacy format)
        dispenses.filter_map do |dispense|
          build_tracking_from_identifiers(resource, dispense)
        end
      end

      private

      # Builds tracking information from MedicationDispense extension array (new format)
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @param dispense [Hash] FHIR MedicationDispense resource
      # @return [Hash, nil] Tracking information hash or nil if no tracking data
      def build_tracking_from_extensions(resource, dispense)
        shipping_extension = find_shipping_extension(dispense)
        return nil unless shipping_extension

        nested_extensions = shipping_extension['extension'] || []
        return nil if nested_extensions.empty?

        tracking_number = find_extension_value(nested_extensions, 'Tracking Number')
        return nil unless tracking_number

        extension_data = {
          tracking_number:,
          carrier: find_extension_value(nested_extensions, 'Delivery Service'),
          shipped_date: find_extension_value(nested_extensions, 'Shipped Date'),
          prescription_name: find_extension_value(nested_extensions, 'Prescription Name'),
          prescription_number: find_extension_value(nested_extensions, 'Prescription Number'),
          ndc_number: find_extension_value(nested_extensions, 'NDC Code')
        }

        build_tracking_hash(resource, extension_data)
      end

      # Finds the shipping-info extension from a dispense's extension array
      #
      # @param dispense [Hash] FHIR MedicationDispense resource
      # @return [Hash, nil] Shipping extension or nil
      def find_shipping_extension(dispense)
        extensions = dispense['extension'] || []
        extensions.find { |ext| ext['url'] == 'http://va.gov/fhir/StructureDefinition/shipping-info' }
      end

      # Finds an extension value by exact URL match
      #
      # @param extensions [Array<Hash>] Array of extension objects
      # @param url [String] The exact URL to search for (e.g., 'Tracking Number')
      # @return [String, nil] The extension valueString or nil if not found
      #
      # Note: Oracle Health uses simple field names as URLs in shipping-info extensions,
      # not full URIs. This method performs exact string matching to avoid ambiguity.
      # Expected URL format: 'Tracking Number', 'Delivery Service', 'NDC Code', etc.
      def find_extension_value(extensions, url)
        extension = extensions.find { |ext| ext['url'] == url }
        extension&.dig('valueString')
      end

      # Builds a tracking hash with fallback to resource extraction methods
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @param data [Hash] Tracking data extracted from extension or identifiers
      # @return [Hash] Tracking information hash
      def build_tracking_hash(resource, data)
        {
          prescription_name: data[:prescription_name] || extract_prescription_name(resource),
          prescription_number: data[:prescription_number] || extract_prescription_number(resource),
          ndc_number: data[:ndc_number] || extract_ndc_code(resource),
          prescription_id: resource['id'],
          tracking_number: data[:tracking_number],
          shipped_date: data[:shipped_date],
          carrier: data[:carrier],
          other_prescriptions: []
        }
      end

      # Extracts NDC code from MedicationRequest or its dispenses
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [String, nil] NDC code or nil if not found
      def extract_ndc_code(resource)
        # Try medicationCodeableConcept coding array
        ndc_from_coding = find_ndc_in_coding(resource.dig('medicationCodeableConcept', 'coding'))
        return ndc_from_coding if ndc_from_coding

        # Fallback: check most recent dispense
        dispense = find_most_recent_medication_dispense(resource)
        return nil unless dispense

        extract_ndc_number(dispense)
      end

      # Finds NDC code in a FHIR coding array
      #
      # @param coding_array [Array<Hash>, nil] Array of coding objects
      # @return [String, nil] NDC code or nil
      def find_ndc_in_coding(coding_array)
        return nil unless coding_array

        ndc_coding = coding_array.find { |c| c['system'] == 'http://hl7.org/fhir/sid/ndc' }
        ndc_coding&.dig('code')
      end

      # Builds tracking information from MedicationDispense identifiers (legacy format)
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @param dispense [Hash] FHIR MedicationDispense resource
      # @return [Hash, nil] Tracking information hash or nil if no tracking number
      def build_tracking_from_identifiers(resource, dispense)
        identifiers = dispense['identifier'] || []

        tracking_number = find_identifier_value(identifiers, 'Tracking Number')
        return nil unless tracking_number

        identifier_data = {
          tracking_number:,
          prescription_number: find_identifier_value(identifiers, 'Prescription Number'),
          shipped_date: find_identifier_value(identifiers, 'Shipped Date'),
          carrier: find_identifier_value(identifiers, 'Carrier'),
          ndc_number: extract_ndc_number(dispense)
        }

        build_tracking_hash(resource, identifier_data)
      end
    end
  end
end
