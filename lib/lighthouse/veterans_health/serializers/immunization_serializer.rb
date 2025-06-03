# frozen_string_literal: true

require 'lighthouse/veterans_health/models/immunization'

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
          attrs.cvx_code = extract_cvx_code(resource.dig('vaccineCode', 'coding'))
          attrs.date = parse_datetime(resource['occurrenceDateTime'])
          attrs.dose_number = extract_dose_number(resource['protocolApplied'])
          attrs.dose_series = extract_dose_series(resource['protocolApplied'])
          attrs.group_name = extract_group_name(resource.dig('vaccineCode', 'text'))
          attrs.manufacturer = resource.dig('manufacturer', 'display')
          attrs.note = parse_notes(resource['note'])
          attrs.reaction = parse_reaction(resource['reaction'])
          attrs.short_description = resource.dig('vaccineCode', 'text')
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

        def self.extract_cvx_code(codings)
          return nil if codings.blank?

          cvx_coding = codings.find { |coding| coding['system'] == 'http://hl7.org/fhir/sid/cvx' }
          cvx_coding&.dig('code')&.to_i
        end

        def self.extract_dose_number(protocol_applied)
          return nil if protocol_applied.blank? || protocol_applied.empty?

          dose_string = protocol_applied.first&.dig('doseNumberString')
          return nil unless dose_string

          match = dose_string.match(/(\d+)/)
          match ? match[1].to_i : nil
        end

        def self.extract_dose_series(protocol_applied)
          return nil if protocol_applied.blank?

          dose_string = protocol_applied.first&.dig('doseNumberString')
          return nil unless dose_string

          match = dose_string.match(/Series (\d+)/)
          match ? match[1].to_i : nil
        end

        def self.extract_group_name(immunization_text)
          return nil if immunization_text.nil?

          # Common immunization group names
          if immunization_text.include?('COVID')
            'COVID-19'
          elsif immunization_text.include?('Influenza') || immunization_text.include?('Flu')
            'Influenza'
          elsif immunization_text.include?('Tetanus') || immunization_text.include?('DTaP')
            'Tetanus'
          elsif immunization_text.include?('Hepatitis')
            'Hepatitis'
          else
            'Other'
          end
        end

        def self.parse_reaction(reactions)
          return nil if reactions.blank?

          reactions.map do |reaction|
            reaction.dig('detail', 'display')
          end.compact.first
        end

        def self.parse_notes(notes)
          return nil if notes.blank?

          notes.pluck('text').compact.join('. ')
        end

        def self.extract_location_id(location)
          return nil if location.nil?

          location['reference'].split('/').last if location.is_a?(Hash) && location['reference']
        end
      end
    end
  end
end
