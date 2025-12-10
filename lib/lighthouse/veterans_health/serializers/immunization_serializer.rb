# frozen_string_literal: true

require 'lighthouse/veterans_health/models/immunization'
require 'digest'

module Lighthouse
  module VeteransHealth
    module Serializers
      class ImmunizationSerializer
        # Transforms a FHIR Immunization resource into an Immunization model
        #
        # @param resource [Hash] the FHIR Immunization resource
        # @return [Lighthouse::VeteransHealth::Models::Immunization] the serialized immunization
        def self.from_fhir(resource)
          return nil if resource.nil?

          immunization = create_base_immunization(resource)
          immunization.attributes = build_immunization_attributes(resource)
          immunization.relationships = build_relationships(resource)

          immunization
        end

        # Creates a basic Immunization object with id and type
        #
        # @param resource [Hash] the FHIR Immunization resource
        # @return [Lighthouse::VeteransHealth::Models::Immunization] the base immunization object
        def self.create_base_immunization(resource)
          immunization = Lighthouse::VeteransHealth::Models::Immunization.new
          immunization.id = resource['id']
          immunization.type = 'immunization'
          immunization
        end

        # Builds the attributes object for an immunization
        #
        # @param resource [Hash] the FHIR Immunization resource
        # @return [Lighthouse::VeteransHealth::Models::ImmunizationAttributes] the populated attributes
        def self.build_immunization_attributes(resource)
          attrs = Lighthouse::VeteransHealth::Models::ImmunizationAttributes.new

          vaccine_code = resource['vaccineCode'] || {}
          protocol_applied = resource['protocolApplied'] || []
          group_name = extract_group_name(vaccine_code)

          attrs.cvx_code = extract_cvx_code(vaccine_code)
          attrs.date = resource['occurrenceDateTime']
          attrs.dose_number = extract_dose_number(protocol_applied)
          attrs.dose_series = extract_dose_series(protocol_applied)
          attrs.group_name = group_name
          attrs.location = extract_location_display(resource['location'])
          attrs.location_id = extract_location_id(resource['location'])
          attrs.manufacturer = extract_manufacturer(resource, group_name)
          attrs.note = extract_note(resource['note'])
          attrs.reaction = extract_reaction(resource['reaction'])
          attrs.short_description = vaccine_code['text']

          attrs
        end

        # Builds the relationships hash for an immunization
        #
        # @param resource [Hash] the FHIR Immunization resource
        # @return [Hash, nil] the relationships hash or nil if no relationships
        def self.build_relationships(resource)
          location_id = extract_location_id(resource['location'])
          return nil unless location_id

          {
            location: {
              data: {
                id: location_id,
                type: 'location'
              }
            }
          }
        end

        # Processes an array of FHIR Immunization resources
        #
        # @param resources [Array<Hash>] an array of FHIR Immunization resources
        # @return [Array<Lighthouse::VeteransHealth::Models::Immunization>] an array of Immunization models
        def self.from_fhir_bundle(response_body)
          return [] if response_body.nil? || response_body['entry'].nil?

          response_body['entry'].map do |entry|
            next if entry['resource'].nil?

            from_fhir(entry['resource'])
          end.compact
        end

        def self.parse_datetime(date_string)
          return nil if date_string.nil?

          begin
            DateTime.parse(date_string)
          rescue Date::Error
            nil
          end
        end

        def self.extract_cvx_code(vaccine_code)
          coding = vaccine_code['coding']&.first
          code = coding && coding['code']
          code.present? ? code.to_i : nil
        end

        def self.extract_dose_number(protocol_applied)
          return nil if protocol_applied.blank?

          series = protocol_applied.first || {}
          series['doseNumberPositiveInt'] || series['doseNumberString']
        end

        def self.extract_dose_series(protocol_applied)
          return nil if protocol_applied.blank?

          series = protocol_applied.first || {}
          series['seriesDosesPositiveInt'] || series['seriesDosesString'] || series['doseNumberString']
        end

        def self.extract_group_name(vaccine_code)
          coding = vaccine_code['coding']
          return nil if coding.nil?

          log_vaccine_code_processing(coding) if Flipper.enabled?(:mhv_vaccine_lighthouse_name_logging)

          extract_group_name_from_codes(coding)
        end

        def self.log_vaccine_code_processing(coding)
          display_hashes = anonymized_display_hashes(coding)
          vaccine_group_lengths = calculate_vaccine_group_lengths(coding)

          Rails.logger.info(
            'Immunizations group_name processing',
            coding_count: coding.length,
            display_hashes:,
            vaccine_group_lengths:
          )
        end

        def self.anonymized_display_hashes(coding)
          coding.map do |v|
            display = v['display']
            display ? Digest::SHA256.hexdigest(display)[0..7] : nil
          end
        end

        def self.calculate_vaccine_group_lengths(coding)
          coding.filter_map do |v|
            display = v['display']
            if display&.start_with?('VACCINE GROUP:')
              # Count only the text after "VACCINE GROUP:"
              text_after_prefix = display.sub(/^VACCINE GROUP:/, '')
              text_after_prefix.length
            end
          end
        end

        def self.extract_group_name_from_codes(coding)
          # First, try to find and extract from VACCINE GROUP: prefix
          filtered_codes = coding.select { |v| v['display']&.start_with?('VACCINE GROUP:') }

          group_name = if filtered_codes.empty?
                         fallback_group_name(coding)
                       else
                         extracted = extract_prefixed_group_name(filtered_codes)
                         # If extraction results in blank/nil, fall back to system priority
                         extracted.presence || fallback_group_name(coding)
                       end

          group_name.presence
        end

        def self.fallback_group_name(coding)
          # Return coding entry based on system priority (excluding VACCINE GROUP entries)
          return nil if coding.nil?

          # Filter out VACCINE GROUP entries
          non_prefixed = coding.reject { |v| v['display']&.start_with?('VACCINE GROUP:') }

          # Priority 1: system = "http://hl7.org/fhir/sid/cvx"
          cvx_entry = non_prefixed.find { |v| v['system'] == 'http://hl7.org/fhir/sid/cvx' && v['display'].present? }
          return cvx_entry['display'] if cvx_entry

          # Priority 2: system contains "fhir.cerner.com"
          cerner_entry = non_prefixed.find { |v| v['system']&.include?('fhir.cerner.com') && v['display'].present? }
          return cerner_entry['display'] if cerner_entry

          # Priority 3: system = "http://hl7.org/fhir/sid/ndc"
          ndc_entry = non_prefixed.find { |v| v['system'] == 'http://hl7.org/fhir/sid/ndc' && v['display'].present? }
          return ndc_entry['display'] if ndc_entry

          # Priority 4: First entry without VACCINE GROUP and with a display value
          non_prefixed.find { |v| v['display'].present? }&.dig('display')
        end

        def self.extract_prefixed_group_name(filtered_codes)
          # Take first filtered entry and remove VACCINE GROUP: prefix
          display = filtered_codes.first&.dig('display')
          return nil if display.nil?

          display.delete_prefix('VACCINE GROUP:').strip
        end

        def self.extract_manufacturer(resource, group_name)
          # Only return manufacturer if group_name is COVID-19 and manufacturer is present
          if group_name == 'COVID-19'
            manufacturer = resource.dig('manufacturer', 'display')
            return manufacturer.presence
          end
          manufacturer.presence
        end

        def self.extract_note(notes)
          return nil if notes.blank?

          note = notes.first
          note && note['text'].present? ? note['text'] : nil
        end

        def self.extract_reaction(reactions)
          return nil if reactions.blank?

          reactions.map { |r| r.dig('detail', 'display') }.compact.join(',')
        end

        def self.extract_location_id(location)
          return nil if location.nil?

          location['reference'].split('/').last if location.is_a?(Hash) && location['reference']
        end

        def self.extract_location_display(location)
          return nil if location.nil?

          location['display'] if location.is_a?(Hash) && location['display']
        end
      end
    end
  end
end
