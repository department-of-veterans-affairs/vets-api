# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    # Helper module for extracting tracking information from Oracle Health FHIR MedicationRequest resources
    # Supports both extension-based (new format) and identifier-based (legacy format) tracking data
    module OracleHealthTrackingHelper
      SHIPPING_INFO_URL = 'http://va.gov/fhir/StructureDefinition/shipping-info'

      # Builds tracking information from MedicationRequest dispenses
      # Tries extension-based format first, falls back to identifier-based format
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Array<Hash>] Array of tracking information hashes
      def build_tracking_information(resource)
        contained_resources = resource['contained'] || []
        dispenses = contained_resources.select { |c| c['resourceType'] == 'MedicationDispense' }

        # Try extension-based tracking first (new format)
        # A single dispense may contain multiple shipping-info extensions (multi-package shipments)
        tracking_from_extensions = dispenses.flat_map do |dispense|
          build_tracking_from_extensions(resource, dispense)
        end

        return tracking_from_extensions if tracking_from_extensions.any?

        # Fallback to identifier-based tracking (legacy format)
        dispenses.filter_map do |dispense|
          build_tracking_from_identifiers(resource, dispense)
        end
      end

      private

      # Builds tracking information from all shipping-info extensions on a MedicationDispense.
      # Multi-package CMOP shipments produce multiple shipping-info extensions per dispense.
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @param dispense [Hash] FHIR MedicationDispense resource
      # @return [Array<Hash>] Array of tracking information hashes (may be empty)
      def build_tracking_from_extensions(resource, dispense)
        find_shipping_extensions(dispense).filter_map do |shipping_extension|
          build_tracking_from_single_extension(resource, shipping_extension)
        end
      end

      # Builds a single tracking hash from one shipping-info extension.
      # Identification is based on the extension URL (SHIPPING_INFO_URL), not individual field names.
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @param shipping_extension [Hash] A single shipping-info extension
      # @return [Hash, nil] Tracking information hash or nil if no tracking number
      def build_tracking_from_single_extension(resource, shipping_extension)
        nested_extensions = shipping_extension['extension'] || []
        return nil if nested_extensions.empty?

        tracking_number = find_extension_value(nested_extensions, 'Tracking Number')
        carrier = find_extension_value(nested_extensions, 'Delivery Service')

        if partial_tracking_info?(tracking_number, carrier)
          log_partial_tracking_info(resource, tracking_number, carrier)
        end

        return nil unless tracking_number

        extension_data = {
          tracking_number:,
          carrier:,
          shipped_date: find_extension_value(nested_extensions, 'Shipped Date'),
          prescription_name: find_extension_value(nested_extensions, 'Prescription Name'),
          prescription_number: find_extension_value(nested_extensions, 'Prescription Number'),
          ndc_number: find_extension_value(nested_extensions, 'NDC Code')
        }

        build_tracking_hash(resource, extension_data)
      end

      # Finds all shipping-info extensions from a dispense's extension array.
      # Multi-package shipments may have multiple shipping-info extensions on one dispense.
      # Identification is based on the extension URL, not individual nested field names.
      #
      # @param dispense [Hash] FHIR MedicationDispense resource
      # @return [Array<Hash>] Matching shipping extensions (may be empty)
      def find_shipping_extensions(dispense)
        extensions = dispense['extension'] || []
        extensions.select { |ext| ext['url'] == SHIPPING_INFO_URL }
      end

      # Checks if tracking info is partial (one of tracking_number/carrier is present but not the other)
      def partial_tracking_info?(tracking_number, carrier)
        tracking_number.present? ^ carrier.present?
      end

      # Logs a warning when partial tracking info is encountered
      def log_partial_tracking_info(resource, tracking_number, carrier)
        Rails.logger.warn(
          'OracleHealthTrackingHelper: Partial tracking info for resource ' \
          "#{resource['id']}. Tracking number: #{tracking_number.present? ? 'present' : 'missing'}, " \
          "carrier: #{carrier.present? ? 'present' : 'missing'}"
        )
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
          complete_date_time: data[:shipped_date],
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
