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

          immunization = Lighthouse::VeteransHealth::Models::Immunization.new
          immunization.id = resource['id']
          immunization.type = 'immunization'
          
          # Create attributes object
          immunization_attributes = Lighthouse::VeteransHealth::Models::ImmunizationAttributes.new
          immunization_attributes.cvx_code = extract_cvx_code(resource.dig('vaccineCode', 'coding'))
          immunization_attributes.date = parse_datetime(resource['occurrenceDateTime'])
          immunization_attributes.dose_number = extract_dose_number(resource['protocolApplied'])
          immunization_attributes.dose_series = extract_dose_series(resource['protocolApplied'])
          immunization_attributes.group_name = extract_group_name(resource.dig('vaccineCode', 'text'))
          immunization_attributes.manufacturer = resource.dig('manufacturer', 'display')
          immunization_attributes.note = parse_notes(resource['note'])
          immunization_attributes.reaction = parse_reaction(resource['reaction'])
          immunization_attributes.short_description = resource.dig('vaccineCode', 'text')
          
          # Set attributes to immunization
          immunization.attributes = immunization_attributes
          
          # Create relationships hash for location
          location_id = extract_location_id(resource['location'])
          if location_id
            immunization.relationships = {
              location: {
                data: {
                  id: location_id,
                  type: 'location'
                },
              }
            }
          end
          
          immunization
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

        private

        def self.parse_datetime(date_string)
          return nil if date_string.nil?

          begin
            DateTime.parse(date_string)
          rescue Date::Error
            nil
          end
        end

        def self.extract_cvx_code(codings)
          return nil if codings.nil? || codings.empty?
          
          cvx_coding = codings.find { |coding| coding['system'] == 'http://hl7.org/fhir/sid/cvx' }
          cvx_coding&.dig('code')&.to_i
        end
        
        def self.extract_dose_number(protocol_applied)
          return nil if protocol_applied.nil? || protocol_applied.empty?
          
          dose_string = protocol_applied.first&.dig('doseNumberString')
          return nil unless dose_string
          
          match = dose_string.match(/(\d+)/)
          match ? match[1].to_i : nil
        end
        
        def self.extract_dose_series(protocol_applied)
          return nil if protocol_applied.nil? || protocol_applied.empty?
          
          dose_string = protocol_applied.first&.dig('doseNumberString')
          return nil unless dose_string
          
          match = dose_string.match(/Series (\d+)/)
          match ? match[1].to_i : nil
        end
        
        def self.extract_group_name(immunization_text)
          return nil if immunization_text.nil?
          
          # Common immunization group names
          if vaccine_text.include?('COVID')
            'COVID-19'
          elsif vaccine_text.include?('Influenza') || vaccine_text.include?('Flu')
            'Influenza'
          elsif vaccine_text.include?('Tetanus') || vaccine_text.include?('DTaP')
            'Tetanus'
          elsif vaccine_text.include?('Hepatitis')
            'Hepatitis'
          else
            'Other'
          end
        end

        def self.parse_reaction(reactions)
          return nil if reactions.nil? || reactions.empty?

          reactions.map do |reaction|
            reaction.dig('detail', 'display')
          end.compact.first
        end

        def self.parse_notes(notes)
          return nil if notes.nil? || notes.empty?

          notes.map { |note| note['text'] }.compact.join('. ')
        end
        
        def self.extract_location_id(location)
          return nil if location.nil?
          
          if location.is_a?(Hash) && location['reference']
            location['reference'].split('/').last
          else
            nil
          end
        end
      end
    end
  end
end