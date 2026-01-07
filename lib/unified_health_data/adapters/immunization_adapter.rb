# frozen_string_literal: true

require_relative '../models/immunization'
require_relative 'date_normalizer'

module UnifiedHealthData
  module Adapters
    class ImmunizationAdapter
      include DateNormalizer

      def initialize(user)
        super()
        @user = user
      end

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
          dose_number: extract_dose_number(protocol_applied),
          dose_series: extract_dose_series(protocol_applied),
          group_name:,
          location: extract_location_display(resource),
          manufacturer: extract_manufacturer(resource),
          note: extract_note(resource['note']),
          reaction: extract_reaction(resource['reaction']),
          short_description: vaccine_code['text'],
          administration_site: extract_site(resource), # e.g. "left arm"
          lot_number: resource['lotNumber'] || nil,
          status: resource['status'] || nil
        )
      end # rubocop:enable Metrics/MethodLength

      private

      def extract_cvx_code(vaccine_code)
        return nil if vaccine_code['coding'].blank?

        # If has multiple vaccine codes, we want the one that maps to CVX, otherwise just take the first one
        coding =
          vaccine_code['coding'].find do |code_entry|
            code_entry['system'] == 'http://hl7.org/fhir/sid/cvx'
          end || vaccine_code['coding'].first
        code = coding && coding['code']
        code.present? ? code.to_i : nil
      end

      def extract_dose_number(protocol_applied)
        # For dose 1 of 3 display
        # dose_number is the "1"
        return nil if protocol_applied.blank?

        series = protocol_applied.first || {}
        # TODO: verify with SCDF team after they investigate
        series['doseNumberPositiveInt'] || series['doseNumberString'] || series['series']
      end

      def extract_dose_series(protocol_applied)
        # For dose 1 of 3 display
        # dose_series is the "3"
        return nil if protocol_applied.blank?

        series = protocol_applied.first || {}
        series['seriesDosesPositiveInt'] ||
          series['seriesDosesString']
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
      #   "doseNumberString": "Unknown",
      #  }
      # ]
      def extract_group_name(resource)
        # Add logging and list all possible names returned and where they were parsed from
        # Log the vaccine group names if the feature flag is enabled
        log_vaccine_group_names(resource) if Flipper.enabled?(:mhv_vaccine_uhd_name_logging, @user)

        # For now check for vaccineCode.text first,
        resource.dig('vaccineCode', 'text') ||
          # else go to fallback methods, based on system priority
          fallback_group_name(resource.dig('vaccineCode', 'coding'))
      end

      def fallback_group_name(coding)
        return nil if coding.nil?

        find_cvx_entry(coding) ||
          find_cerner_entry(coding) ||
          find_ndc_entry(coding) ||
          find_first_display_entry(coding)
      end

      def find_cvx_entry(entries)
        entry = entries.find do |v|
          system = v[:system] || v['system']
          display = v[:display] || v['display']
          system == 'http://hl7.org/fhir/sid/cvx' && display.present?
        end
        entry ? (entry[:display] || entry['display']) : nil
      end

      def find_cerner_entry(entries)
        entry = entries.find do |v|
          display = v[:display] || v['display']
          system = v[:system] || v['system']
          next false unless display.present? && system.present?

          cerner_system?(system)
        end
        entry ? (entry[:display] || entry['display']) : nil
      end

      def cerner_system?(system)
        uri = URI.parse(system)
        host = uri.host
        host == 'fhir.cerner.com' || host&.end_with?('.fhir.cerner.com')
      rescue URI::InvalidURIError
        false
      end

      def find_ndc_entry(entries)
        entry = entries.find do |v|
          system = v[:system] || v['system']
          display = v[:display] || v['display']
          system == 'http://hl7.org/fhir/sid/ndc' && display.present?
        end
        entry ? (entry[:display] || entry['display']) : nil
      end

      def extract_manufacturer(resource)
        return nil if resource['manufacturer'].nil?

        resource.dig('manufacturer', 'display')
      end

      def extract_note(notes)
        return nil if notes.blank?

        # Send all note text as a single string for VAHB backward compatibility
        notes.map { |note| note['text'].presence }.compact.join(', ')
      end

      # None of the sample vaccines have reactions so not sure where this will be located, if we get it at all
      def extract_reaction(reactions)
        return nil if reactions.blank?

        reactions.map { |r| r.dig('detail', 'display') }.compact.join(', ')
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
          find_first_display_entry(resource.dig('site', 'coding'))
      end

      # Logs possible group names for Vaccines to PersonalInformationLog
      # for secure debugging of parsing mechanism
      def log_vaccine_group_names(record)
        data = {
          vaccine_code_text: record.dig('vaccineCode', 'text'),
          vaccine_codes_display: record.dig('vaccineCode', 'coding').map { |c| c['display'] },
          target_disease_text: record.dig('protocolApplied', 0, 'targetDisease', 0, 'text'),
          service: 'unified_health_data'
        }

        PersonalInformationLog.create!(
          error_class: 'UHD Vaccine Group Names',
          data:
        )
      rescue => e
        # Log any errors in creating the PersonalInformationLog without exposing PII
        Rails.logger.error(
          "Error creating PersonalInformationLog for vaccine name issue: #{e.class.name}",
          { service: 'unified_health_data', backtrace: e.backtrace.first(5) }
        )
      end

      def find_first_display_entry(entries)
        return nil if entries.nil?

        entry = entries.find do |v|
          display = v[:display] || v['display']
          display.present?
        end
        entry&.dig(:display) || entry&.dig('display')
      end
    end
  end
end
