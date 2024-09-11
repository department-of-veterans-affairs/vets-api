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
              reactions: reactions(allergy_info['reaction'])
            )
          end
        end

        private

        def clinical_status(attributes)
          values = Array.wrap(attributes['coding'])
          coding = values.map do |code|
            Mobile::V0::AllergyIntolerance::ClinicalStatus::Coding.new(system: code['system'], code: code['code'])
          end

          Mobile::V0::AllergyIntolerance::ClinicalStatus.new(coding:)
        end

        def code(attributes)
          values = Array.wrap(attributes['coding'])
          coding = values.map do |code|
            Mobile::V0::AllergyIntolerance::Code::Coding.new(system: code['system'], code: code['code'],
                                                             display: code['display'])
          end

          Mobile::V0::AllergyIntolerance::Code.new(coding:, text: attributes['text'])
        end

        def patient(attributes)
          Mobile::V0::AllergyIntolerance::Patient.new(reference: attributes['reference'],
                                                      display: attributes['display'])
        end

        def recorder(attributes)
          Mobile::V0::AllergyIntolerance::Recorder.new(reference: attributes['reference'],
                                                       display: attributes['display'])
        end

        def notes(attributes)
          Array.wrap(attributes).map do |note|
            author_reference = Mobile::V0::AllergyIntolerance::Note::AuthorReference.new(
              reference: note.dig('authorReference', 'reference'),
              display: note.dig(
                'authorReference', 'display'
              )
            )
            Mobile::V0::AllergyIntolerance::Note.new(author_reference:, time: note['time'], text: note['text'])
          end
        end

        def reactions(attributes)
          Array.wrap(attributes).map do |reaction|
            substance_list = Array.wrap(reaction.dig('substance', 'coding'))

            coding = substance_list.map do |code|
              Mobile::V0::AllergyIntolerance::Reaction::Substance::Coding.new(
                system: code['system'],
                code: code['code'], display: code['display']
              )
            end
            substance = Mobile::V0::AllergyIntolerance::Reaction::Substance.new(coding:,
                                                                                text: reaction.dig(
                                                                                  'substance', 'text'
                                                                                ))

            manifestation = manifestations(reaction)
            Mobile::V0::AllergyIntolerance::Reaction.new(substance:, manifestation:)
          end
        end

        def manifestations(reaction)
          manifestation_list = Array.wrap(reaction['manifestation'])

          manifestation_list.map do |manifestation_hash|
            coding_list = Array.wrap(manifestation_hash['coding'])

            coding = coding_list.map do |code|
              Mobile::V0::AllergyIntolerance::Reaction::Manifestation::Coding.new(
                system: code['system'],
                code: code['code'], display: code['display']
              )
            end

            Mobile::V0::AllergyIntolerance::Reaction::Manifestation.new(coding:, text: manifestation_hash['text'])
          end
        end
      end
    end
  end
end
