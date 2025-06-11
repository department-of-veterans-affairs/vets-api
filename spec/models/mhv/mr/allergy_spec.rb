# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MHV::MR::Allergy, type: :model do
  describe '.from_fhir' do
    context 'with a valid FHIR::AllergyIntolerance resource' do
      subject(:allergy) { described_class.from_fhir(fhir_allergy) }

      let(:location_resource) do
        FHIR::Location.new(
          id: 'loc-1',
          name: 'Test Location'
        )
      end

      let(:observed_ext) do
        FHIR::Extension.new(
          url: 'http://example.org/fhir/StructureDefinition/allergyObservedHistoric',
          valueCode: 'o'
        )
      end

      let(:recorder_ext) do
        FHIR::Extension.new(
          url: 'http://hl7.org/fhir/StructureDefinition/alternate-reference',
          valueReference: FHIR::Reference.new(reference: '#loc-1')
        )
      end

      let(:recorder_ref) do
        FHIR::Reference.new(
          reference: '#loc-1',
          extension: [recorder_ext],
          display: 'Dr. Allergy'
        )
      end

      let(:fhir_allergy) do
        FHIR::AllergyIntolerance.new(
          id: 'a1',
          code: FHIR::CodeableConcept.new(text: 'Peanut Allergy'),
          recordedDate: '2021-05-10',
          category: %w[food environment],
          reaction: [
            FHIR::AllergyIntolerance::Reaction.new(
              manifestation: [
                FHIR::CodeableConcept.new(text: 'rash'),
                FHIR::CodeableConcept.new(text: 'anaphylaxis')
              ]
            )
          ],
          extension: [observed_ext],
          note: [FHIR::Annotation.new(text: 'Carry epi pen')],
          recorder: recorder_ref,
          contained: [location_resource]
        )
      end

      it 'maps id correctly' do
        expect(allergy.id).to eq('a1')
      end

      it 'maps name correctly' do
        expect(allergy.name).to eq('Peanut Allergy')
      end

      it 'maps date correctly' do
        expect(allergy.date).to eq('2021-05-10')
      end

      it 'maps categories correctly' do
        expect(allergy.categories).to eq(%w[food environment])
      end

      it 'maps reactions correctly' do
        expect(allergy.reactions).to eq(%w[rash anaphylaxis])
      end

      it 'maps location correctly' do
        expect(allergy.location).to eq('Test Location')
      end

      it 'maps observedHistoric correctly' do
        expect(allergy.observedHistoric).to eq('o')
      end

      it 'maps notes correctly' do
        expect(allergy.notes).to eq('Carry epi pen')
      end

      it 'maps provider correctly' do
        expect(allergy.provider).to eq('Dr. Allergy')
      end
    end

    context 'when given nil' do
      it 'returns nil' do
        expect(described_class.from_fhir(nil)).to be_nil
      end
    end

    context 'with missing fields and contained resources' do
      subject(:allergy) { described_class.from_fhir(fhir_allergy) }

      let(:fhir_allergy) { FHIR::AllergyIntolerance.new(id: 'b2') }

      it 'sets id correctly' do
        expect(allergy.id).to eq('b2')
      end

      it 'defaults name to nil' do
        expect(allergy.name).to be_nil
      end

      it 'defaults date to nil' do
        expect(allergy.date).to be_nil
      end

      it 'defaults categories to an empty array' do
        expect(allergy.categories).to eq([])
      end

      it 'defaults reactions to an empty array' do
        expect(allergy.reactions).to eq([])
      end

      it 'defaults location to nil' do
        expect(allergy.location).to be_nil
      end

      it 'defaults observedHistoric to nil' do
        expect(allergy.observedHistoric).to be_nil
      end

      it 'defaults notes to nil' do
        expect(allergy.notes).to be_nil
      end

      it 'defaults provider to nil' do
        expect(allergy.provider).to be_nil
      end
    end
  end
end
