# frozen_string_literal: true

require_relative '../models/immunization'
require_relative 'date_normalizer'

module UnifiedHealthData
  module Adapters
    class ImmunizationAdapter
      include DateNormalizer

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
        date_value = resource['occurrenceDateTime'] || nil
        vaccine_code = resource['vaccineCode'] || {}
        protocol_applied = resource['protocolApplied'] || []
        group_name = extract_group_name(resource)

        UnifiedHealthData::Immunization.new(
          id: resource['id'],
          cvx_code: extract_cvx_code(vaccine_code),
          date: date_value,
          sort_date: normalize_date_for_sorting(date_value),
          dose_number: extract_dose_number(protocol_applied), # not sure this is accurate
          dose_series: extract_dose_series(protocol_applied), # not sure this is accurate
          group_name:,
          location: extract_location_display(resource),
          location_id: extract_location_id(resource['location']), #  not sure it's needed
          manufacturer: extract_manufacturer(resource),
          note: extract_note(resource['note']),
          reaction: extract_reaction(resource['reaction']),
          short_description: vaccine_code['text'],
          administration_site: extract_site(resource), # e.g. "left arm"
          lot_number: resource['lotNumber'] || nil,
          status: resource['status'] || nil # Status of the record ??
        )
      end # rubocop:enable Metrics/MethodLength

      private

      def extract_cvx_code(vaccine_code)
        return nil if vaccine_code['coding'].blank?

        # OH data has multiple vaccine codes, but we want the one that maps to CVX
        coding = if vaccine_code['coding'].count > 1
                   vaccine_code['coding'].find do |code_entry|
                     code_entry['system'] == 'http://hl7.org/fhir/sid/cvx'
                   end
                 else
                   # VistA data has only one coding entry
                   vaccine_code['coding'].first
                 end
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
      def extract_group_name(resource)
        # OH data: find any protocolApplied entry with targetDisease
        protocol_applied = resource['protocolApplied']
        if protocol_applied.is_a?(Array)
          target_disease_text = protocol_applied
                                .find { |entry| entry['targetDisease'].present? }
                                &.dig('targetDisease', 0, 'text')
          return target_disease_text if target_disease_text
        end

        # Otherwise, fall back to vaccineCode.text
        resource.dig('vaccineCode', 'text')
      end

      # Are we still only returning for Covid vaccines?
      def extract_manufacturer(resource)
        return nil if resource['manufacturer'].nil?

        resource.dig('manufacturer', 'display')
      end

      def extract_note(notes)
        return nil if notes.blank?

        # TODO: Verify that we only want the first, or if we return all in an array of strings
        note = notes.first
        note && note['text'].present? ? note['text'] : nil
      end

      # None of the sample vaccines have reactions so not sure where this will be located
      # According to slack convo SCDF might not return any reactions?
      def extract_reaction(reactions)
        return nil if reactions.blank?

        reactions.map { |r| r.dig('detail', 'display') }.compact.join(',')
      end

      # This might not be necessary, the location_id is only used to retrieve LH location data
      def extract_location_id(location)
        return nil if location.nil?

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
        location['reference'].split('/').last if location['reference']&.include?('/')
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
      def extract_location_display(resource)
        # Check if any performer has an Organization reference - use its longer display name
        performers = resource['performer']
        if performers.is_a?(Array)
          org_performer = performers.find do |performer|
            performer.dig('actor', 'reference')&.start_with?('Organization/')
          end
          return org_performer.dig('actor', 'display') if org_performer
        end

        # Fall back to location display (VistA data or OH truncated name)
        resource.dig('location', 'display')
      end

      def extract_site(resource)
        resource.dig('site', 'text') ||
          resource.dig('site', 'coding')&.first&.dig('display')
      end
    end
  end
end
