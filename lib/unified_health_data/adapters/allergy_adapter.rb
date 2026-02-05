# frozen_string_literal: true

require_relative '../models/allergy'
require_relative 'date_normalizer'

module UnifiedHealthData
  module Adapters
    class AllergyAdapter
      include DateNormalizer
      FHIR_RESOURCE_TYPES = {
        BUNDLE: 'Bundle',
        DIAGNOSTIC_REPORT: 'DiagnosticReport',
        DOCUMENT_REFERENCE: 'DocumentReference',
        LOCATION: 'Location',
        OBSERVATION: 'Observation',
        ORGANIZATION: 'Organization',
        PRACTITIONER: 'Practitioner'
      }.freeze

      # Parses allergy records from FHIR AllergyIntolerance resources
      #
      # Always excludes allergies without a name (from code.coding[0].display or code.text).
      # When filter_by_status is true, also excludes allergies without 'active' clinicalStatus.
      #
      # @param records [Array] Array of FHIR entry records
      # @param filter_by_status [Boolean] When true, also requires 'active' clinical status.
      #   Defaults to true.
      # @return [Array<UnifiedHealthData::Allergy>] Array of parsed allergy objects
      def parse(records, filter_by_status: true)
        return [] if records.blank?

        filtered = records.select do |record|
          resource = record['resource']
          next false unless resource && resource['resourceType'] == 'AllergyIntolerance'
          next true unless filter_by_status

          active_status?(resource)
        end
        parsed = filtered.map { |record| parse_single_allergy(record, filter_by_status: false) }
        parsed.compact
      end

      # Parses a single allergy record from a FHIR AllergyIntolerance resource
      #
      # Always returns nil for allergies without a name (from code.coding[0].display or code.text).
      # When filter_by_status is true, also returns nil for allergies without 'active' clinicalStatus.
      #
      # @param record [Hash] A single FHIR entry record
      # @param filter_by_status [Boolean] When true, also requires 'active' clinical status.
      #   Defaults to true.
      # @return [UnifiedHealthData::Allergy, nil] Parsed allergy object or nil if filtered/invalid
      def parse_single_allergy(record, filter_by_status: true)
        return nil if record.nil? || record['resource'].nil?

        resource = record['resource']

        # Filter by active status if enabled
        return nil if filter_by_status && !active_status?(resource)

        # Extract name and skip if blank
        name = extract_name(resource)
        return nil if name.blank?

        date_value = resource['onsetDateTime'] || resource['recordedDate'] || nil

        UnifiedHealthData::Allergy.new(
          id: resource['id'],
          name:,
          # VistA samples have neither; OH has both but each are different
          date: date_value,
          sort_date: normalize_date_for_sorting(date_value),
          categories: resource['category'] || [],
          reactions: extract_reactions(resource),
          location: extract_location(resource), # No contained array or location names in samples
          observedHistoric: extract_observed_historic(resource), # Only in VistA data
          notes: extract_allergy_comments(resource),
          provider: extract_allergy_provider(resource)
        )
      end

      private

      # Checks if the allergy has an active clinical status
      #
      # @param resource [Hash] FHIR AllergyIntolerance resource
      # @return [Boolean] true if clinicalStatus is 'active'
      def active_status?(resource)
        clinical_status = resource.dig('clinicalStatus', 'coding', 0, 'code')
        clinical_status == 'active'
      end

      # Extracts the allergy name from code.coding[0].display or code.text
      #
      # @param resource [Hash] FHIR AllergyIntolerance resource
      # @return [String, nil] the allergy name or nil if not present
      def extract_name(resource)
        resource.dig('code', 'coding', 0, 'display') || resource.dig('code', 'text')
      end

      def extract_reactions(resource)
        return [] if resource['reaction'].blank?

        if resource['reaction'][0].is_a?(Hash)
          resource['reaction'].map { |reaction| reaction.dig('manifestation', 0, 'text') }.compact
        else
          resource['reaction'] # Not sure if this is necessary, but handle if array of strings
        end
      end

      def extract_allergy_comments(resource)
        return [] unless resource['note']

        if resource['note'].is_a?(Array)
          resource['note'].map { |note| note['text'] }.compact
        else
          [resource['note']['text']].compact
        end
      end

      # TODO: OH doesn't have something like this, FE is already ignoring for LH data
      def extract_observed_historic(resource)
        if resource['extension'].is_a?(Array)
          ext_item = resource['extension'].find do |item|
            item['url']&.include?('allergyObservedHistoric')
          end
          ext_item['valueCode'] || nil
        end
      end

      def extract_allergy_provider(resource)
        # TODO: This won't work, allergy samples have no contained array

        # reference = resource.dig('recorder', 'reference')
        # return nil unless reference && resource['contained']
        # provider = find_contained(
        #   record,
        #   reference,
        #   FHIR_RESOURCE_TYPES[:PRACTITIONER]
        # )
        # name = provider['name']&.find { |n| n['text'] }
        # format_practitioner_name(name) if name

        format_practitioner_name(resource['recorder']['display'])
      rescue
        nil
      end

      # TODO: needs work - no locations or facilities in sample data
      def extract_location(record)
        # OH has the encounter reference, but there is no contained array in either VistA or OH samples to match it to
        resource = find_contained(record, record['encounter']['reference'], FHIR_RESOURCE_TYPES[:LOCATION])
        resource['name'] || nil
      rescue
        nil
      end

      # None of the sample data has a contained array, so probably unnecessary
      def find_contained(record, reference, type = nil)
        return nil unless reference && record['contained']

        if reference.start_with?('#')
          # Reference is in the format #mhv-resourceType-id
          target_id = reference.delete_prefix('#')
          resource = record['contained'].detect { |res| res['id'] == target_id }
          nil unless resource && resource['resourceType'] == type
        else
          # Reference is in the format ResourceType/id
          type_id = reference.split('/')
          resource = record['contained'].detect { |res| res['id'] == type_id.last }
          return nil unless resource && (resource['resourceType'] == type_id.first || resource['resourceType'] == type)
        end
        resource
      end

      def format_practitioner_name(name)
        if name.is_a?(Hash)
          if name.key?('family') && name.key?('given')
            firstname = name['given']&.join(' ')
            lastname = name['family']
            return "#{firstname} #{lastname}"
          end

          parts = name['text']&.split(',')
          return name['text'] if parts&.length != 2

          lastname, firstname = parts
          return "#{firstname} #{lastname}"
        end

        parts = name.split(',')
        return name if parts.length != 2

        lastname, firstname = parts
        "#{firstname} #{lastname}"
      rescue
        nil
      end
    end
  end
end
