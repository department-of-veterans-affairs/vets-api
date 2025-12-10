# frozen_string_literal: true

require_relative '../models/immunization'
require_relative 'date_normalizer'

module UnifiedHealthData
  module Adapters
    class ImmunizationAdapter
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

      def parse(records)
        return [] if records.blank?

        filtered = records.select do |record|
          record['resource'] && record['resource']['resourceType'] == 'Immunization'
        end
        parsed = filtered.map { |record| parse_single_immunization(record) }
        parsed.compact
      end

      def parse_single_immunization(record) # rubocop:disable Metrics/MethodLength
        return nil if record.nil? || record['resource'].nil?

        resource = record['resource']
        date_value = resource['occurrenceDateTime'] || resource['recordedDate'] || nil
        vaccine_code = resource['vaccineCode'] || {}
        protocol_applied = resource['protocolApplied'] || []
        group_name = extract_group_name(vaccine_code) # PROBLEMATICAL

        UnifiedHealthData::Immunization.new(
          id: resource['id'],
          cvx_code: extract_cvx_code(vaccine_code),
          date: date_value,
          sort_date: normalize_date_for_sorting(date_value),
          dose_number: extract_dose_number(protocol_applied),
          dose_series: extract_dose_series(protocol_applied),
          group_name:,
          location: extract_location_display(resource['location']),
          location_id: extract_location_id(resource['location']),
          manufacturer: extract_manufacturer(resource, group_name), # PROBLEMATICAL
          note: extract_note(resource['note']), # PROBLEMATICAL
          reaction: extract_reaction(resource['reaction']), # PROBLEMATICAL
          short_description: vaccine_code['text']
        )
      end # rubocop:enable Metrics/MethodLength

      private

      def extract_cvx_code(vaccine_code)
        coding = vaccine_code['coding']&.first
        code = coding && coding['code']
        code.present? ? code.to_i : nil
      end

      def extract_dose_number(protocol_applied)
        return nil if protocol_applied.blank?

        series = protocol_applied.first || {}
        # TODO: not sure "series" will always be accurate
        series['doseNumberPositiveInt'] || series['doseNumberString'] || series['series']
      end

      def extract_dose_series(protocol_applied)
        return nil if protocol_applied.blank?

        series = protocol_applied.first || {}
        series['doseNumberString'] || # this aligns with OH data
          series['series'] || # this aligns with VistA data
          series['seriesDosesPositiveInt'] || # this aligns with legacy data
          series['seriesDosesString'] # this aligns with legacy data
      end

      # TODO: none of the sample vaccines have 'VACCINE GROUP: '
      # VistA has the name of the vaccine in the vaccineCode text:
      # "vaccineCode": {
      #     "coding": [
      #         {
      #             "code": "91316",
      #             "display": "SARSCOV2 VAC BVL 10MCG/0.2ML"
      #         }
      #     ],
      #     "text": "COVID-19 (MODERNA), MRNA, LNP-S, BIVALENT, PF, 10 MCG/0.2 ML"
      # },
      # OH has the name of the vaccine in the protocolApplied array:
      # "protocolApplied": [
      #  {
      #    "targetDisease": [
      #      {
      #        "coding": [
      #          {
      #            "system": "...",
      #            "code": "840539006",
      #            "display": "poliovirus vaccine, unspecified formulation"
      #          }
      #         ],
      #       "text": "Polio"
      #       }
      #     ],
      #   "doseNumberString": "1",
      #  }
      # ]
      def extract_group_name(vaccine_code)
        coding = vaccine_code['coding'] || []
        filtered = coding.select { |v| v['display']&.include?('VACCINE GROUP: ') }

        if filtered.empty?
          group_name = vaccine_code.dig('coding', 1, 'display') || vaccine_code.dig('coding', 0, 'display')
        else
          group_name = filtered.dig(0, 'display')
          group_name&.slice!('VACCINE GROUP: ')
        end
        group_name.presence
      end

      # None of the sample vaccines have manufacturer so not sure where this will be located
      def extract_manufacturer(resource, group_name)
        # Only return manufacturer if group_name is COVID-19 and manufacturer is present
        if group_name == 'COVID-19'
          manufacturer = resource.dig('manufacturer', 'display')
          return manufacturer.presence
        end
        manufacturer.presence
      end

      # None of the samples have notes so not sure where this will be located
      def extract_note(notes)
        return nil if notes.blank?

        note = notes.first
        note && note['text'].present? ? note['text'] : nil
      end

      # None of the sample vaccines have reactions so not sure where this will be located
      def extract_reaction(reactions)
        return nil if reactions.blank?

        reactions.map { |r| r.dig('detail', 'display') }.compact.join(',')
      end

      # VistA has only the name as a string for reference (same string as the display)
      # "location": {
      #    "reference": "GREELEY NURSE",
      #    "display": "GREELEY NURSE"
      # },
      # OH has the reference as "Location/id" + display as a truncated name
      # "location": {
      #     "reference": "Location/353977013",
      #     "display": "556 JAL IL VA"
      # },
      # But the performer array has a more complete location name
      # "performer": [
      #   {
      #     "actor": {
      #        "reference": "Organization/2044131",
      #        "display": "556 Captain James A Lovell IL VA Medical Center"
      #     }
      #   }
      # ],
      def extract_location_id(location)
        return nil if location.nil?

        location['reference'].split('/').last if location.is_a?(Hash) && location['reference']
      end

      def extract_location_display(location)
        return nil if location.nil?

        location['display'] if location.is_a?(Hash) && location['display']
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
    end
  end
end
