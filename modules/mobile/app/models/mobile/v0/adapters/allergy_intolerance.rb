# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class AllergyIntolerance
        def parse(allergies_info)
          Array.wrap(allergies_info).map do |allergy|
            allergy_info = allergy['resource']
            Mobile::V0::AllergyIntolerance.new(
              id: allergy_info['id'],
              resourceType: allergy_info['resourceType'],
              type: allergy_info['type'],
              clinicalStatus: clinical_status(allergy_info['clinicalStatus']),
              code: code(allergy_info['code']),
              recordedDate: allergy_info['recordedDate'],
              patient: patient(allergy_info['patient']),
              recorder: recorder(allergy_info['recorder']),
              notes: notes(allergy_info['note']),
              reactions: reactions(allergy_info['reaction']),
              category: allergy_info['category']
            )
          end
        end

        private

        def clinical_status(attributes)
          values = Array.wrap(attributes['coding'])
          coding = values.map do |code|
            {
              system: code['system'], code: code['code']
            }
          end

          { coding: }
        end

        def code(attributes)
          values = Array.wrap(attributes['coding'])
          coding = values.map do |code|
            {
              system: code['system'],
              code: code['code'],
              display: code['display']
            }
          end

          { coding:, text: attributes['text'] }
        end

        def patient(attributes)
          {
            reference: attributes['reference'],
            display: attributes['display']
          }
        end

        def recorder(attributes)
          {
            reference: attributes['reference'],
            display: attributes['display']
          }
        end

        def notes(attributes)
          Array.wrap(attributes).map do |note|
            {
              author_reference: {
                reference: note.dig('authorReference', 'reference'),
                display: note.dig('authorReference', 'display')
              },
              time: note['time'],
              text: note['text']
            }
          end
        end

        def reactions(attributes)
          Array.wrap(attributes).map do |reaction|
            substance_list = Array.wrap(reaction.dig('substance', 'coding'))

            substance_coding = substance_list.map do |code|
              {
                system: code['system'],
                code: code['code'],
                display: code['display']
              }
            end

            {
              substance: {
                text: reaction.dig('substance', 'text'),
                coding: substance_coding
              },
              manifestation: manifestations(reaction)
            }
          end
        end

        def manifestations(reaction)
          manifestation_list = Array.wrap(reaction['manifestation'])

          manifestation_list.map do |manifestation_hash|
            coding_list = Array.wrap(manifestation_hash['coding'])

            coding = coding_list.map do |code|
              {
                system: code['system'],
                code: code['code'],
                display: code['display']
              }
            end

            { coding:, text: manifestation_hash['text'] }
          end
        end
      end
    end
  end
end
