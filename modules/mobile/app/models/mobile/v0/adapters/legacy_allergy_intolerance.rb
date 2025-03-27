# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class LegacyAllergyIntolerance
        def parse(allergies_info)
          Array.wrap(allergies_info).map do |allergy|
            allergy_info = allergy['resource']
            Mobile::V0::LegacyAllergyIntolerance.new(
              id: allergy_info['id'],
              resourceType: allergy_info['resourceType'],
              type: allergy_info['type'],
              clinicalStatus: clinical_status(allergy_info['clinicalStatus']),
              code: code(allergy_info['code']),
              recordedDate: allergy_info&.dig('recordedDate'),
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
          return { 'coding' => [] } if attributes.blank?

          values = Array.wrap(attributes['coding'])
          coding_hash = values.map do |code|
            {
              'system' => code['system'],
              'code' => code['code']
            }
          end

          { 'coding' => coding_hash }
        end

        def code(attributes)
          values = Array.wrap(attributes['coding'])
          coding_hash = values.map do |code|
            {
              'system' => code['system'],
              'code' => code['code'],
              'display' => code['display']
            }
          end

          {
            'coding' => coding_hash,
            'text' => attributes['text']
          }
        end

        def patient(attributes)
          {
            'reference' => attributes&.dig('reference'),
            'display' => attributes&.dig('display')
          }
        end

        def recorder(attributes)
          {
            'reference' => attributes&.dig('reference'),
            'display' => attributes&.dig('display')
          }
        end

        def notes(attributes)
          return [] if attributes.blank?

          Array.wrap(attributes).map do |note|
            {
              'authorReference' => {
                'reference' => note.dig('authorReference', 'reference'),
                'display' => note.dig('authorReference', 'display')
              },
              'time' => note['time'],
              'text' => note['text']
            }
          end
        end

        def reactions(attributes)
          return [] if attributes.blank?

          Array.wrap(attributes).map do |reaction|
            substance = Array.wrap(reaction.dig('substance', 'coding'))

            substance_hash = substance.map do |code|
              {
                'system' => code['system'],
                'code' => code['code'],
                'display' => code['display']
              }
            end

            {
              'substance' => {
                'coding' => substance_hash,
                'text' => reaction.dig('substance', 'text')
              },
              'manifestation' => manifestation_hash(reaction['manifestation'])
            }
          end
        end

        def manifestation_hash(manifestation_info)
          Array.wrap(manifestation_info).map do |manifestation|
            coding = Array.wrap(manifestation['coding'])

            coding_hash = coding.map do |code|
              {
                'system' => code['system'],
                'code' => code['code'],
                'display' => code['display']
              }
            end

            {
              'coding' => coding_hash,
              'text' => manifestation['text']
            }
          end
        end
      end
    end
  end
end
