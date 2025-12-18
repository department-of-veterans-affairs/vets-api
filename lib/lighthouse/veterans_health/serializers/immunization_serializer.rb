# frozen_string_literal: true

require 'lighthouse/veterans_health/models/immunization'
require 'lighthouse/veterans_health/utils/vaccine_group_name_utils'

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
          Lighthouse::VeteransHealth::Utils::VaccineGroupNameUtils.extract_group_name(vaccine_code)
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
