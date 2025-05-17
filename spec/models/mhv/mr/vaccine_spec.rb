# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MHV::MR::Vaccine do
  describe '.from_fhir' do
    context 'with a valid FHIR::Immunization resource' do
      subject(:vaccine) { described_class.from_fhir(immunization) }

      let(:location_resource) do
        FHIR::Location.new(
          id: 'in-location-2',
          name: 'Test Location'
        )
      end

      let(:observation_resource) do
        FHIR::Observation.new(
          id: 'in-reaction-2',
          code: FHIR::CodeableConcept.new(text: 'FEVER')
        )
      end

      let(:immunization) do
        FHIR::Immunization.new(
          id: '12345',
          vaccineCode: FHIR::CodeableConcept.new(text: 'TEST VACCINE'),
          occurrenceDateTime: '2023-10-27T10:00:00-04:00',
          location: FHIR::Reference.new(reference: '#in-location-2'),
          manufacturer: FHIR::Reference.new(display: 'Test Manufacturer'),
          reaction: [
            FHIR::Immunization::Reaction.new(
              detail: FHIR::Reference.new(reference: '#in-reaction-2')
            )
          ],
          note: [
            FHIR::Annotation.new(text: 'Note 1'),
            FHIR::Annotation.new(text: 'Note 2')
          ],
          contained: [location_resource, observation_resource]
        )
      end

      it 'maps id correctly' do
        expect(vaccine.id).to eq('12345')
      end

      it 'maps name correctly' do
        expect(vaccine.name).to eq('TEST VACCINE')
      end

      it 'maps date_received correctly' do
        expect(vaccine.date_received).to eq('2023-10-27T10:00:00-04:00')
      end

      it 'maps location correctly' do
        expect(vaccine.location).to eq('Test Location')
      end

      it 'maps manufacturer correctly' do
        expect(vaccine.manufacturer).to eq('Test Manufacturer')
      end

      it 'maps reactions correctly' do
        expect(vaccine.reactions).to eq('FEVER')
      end

      it 'maps notes correctly' do
        expect(vaccine.notes).to eq(['Note 1', 'Note 2'])
      end
    end

    context 'when given nil' do
      it 'returns nil' do
        expect(described_class.from_fhir(nil)).to be_nil
      end
    end

    context 'with missing contained resources and attributes' do
      subject(:vaccine) { described_class.from_fhir(immunization) }

      let(:immunization) { FHIR::Immunization.new(id: '1') }

      it 'sets id correctly' do
        expect(vaccine.id).to eq('1')
      end

      it 'defaults name to nil' do
        expect(vaccine.name).to be_nil
      end

      it 'defaults date_received to nil' do
        expect(vaccine.date_received).to be_nil
      end

      it 'defaults location to an empty string' do
        expect(vaccine.location).to be_nil
      end

      it 'defaults manufacturer to an empty string' do
        expect(vaccine.manufacturer).to be_nil
      end

      it 'defaults reactions to an empty string' do
        expect(vaccine.reactions).to be_nil
      end

      it 'defaults notes to an empty array' do
        expect(vaccine.notes).to eq([])
      end
    end
  end
end
