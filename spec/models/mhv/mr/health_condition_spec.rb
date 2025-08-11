# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MHV::MR::HealthCondition, type: :model do
  describe '.from_fhir' do
    context 'with a valid FHIR::Condition resource' do
      subject(:health_condition) { described_class.from_fhir(fhir_condition) }

      let(:location_resource) do
        FHIR::Location.new(
          id: 'loc-1',
          name: 'Test Facility'
        )
      end

      let(:practitioner_resource) do
        FHIR::Practitioner.new(
          id: 'prov-1',
          name: [FHIR::HumanName.new(text: 'Dr. Test')]
        )
      end

      let(:extension) do
        FHIR::Extension.new(
          url: 'http://hl7.org/fhir/StructureDefinition/alternate-reference',
          valueReference: FHIR::Reference.new(reference: '#loc-1')
        )
      end

      let(:recorder_reference) do
        FHIR::Reference.new(
          reference: '#prov-1',
          extension: [extension]
        )
      end

      let(:fhir_condition) do
        FHIR::Condition.new(
          id: '123',
          code: FHIR::CodeableConcept.new(text: 'Test Condition'),
          recordedDate: '2022-04-29',
          recorder: recorder_reference,
          contained: [location_resource, practitioner_resource],
          note: [
            FHIR::Annotation.new(text: 'Note one'),
            FHIR::Annotation.new(text: 'Note two')
          ]
        )
      end

      it 'maps id correctly' do
        expect(health_condition.id).to eq('123')
      end

      it 'maps name correctly' do
        expect(health_condition.name).to eq('Test Condition')
      end

      it 'maps date correctly' do
        expect(health_condition.date).to eq('2022-04-29')
      end

      it 'maps facility correctly' do
        expect(health_condition.facility).to eq('Test Facility')
      end

      it 'maps provider correctly' do
        expect(health_condition.provider).to eq('Dr. Test')
      end

      it 'maps comments correctly' do
        expect(health_condition.comments).to eq(['Note one', 'Note two'])
      end
    end

    context 'when given nil' do
      it 'returns nil' do
        expect(described_class.from_fhir(nil)).to be_nil
      end
    end

    context 'with missing fields and contained resources' do
      subject(:health_condition) { described_class.from_fhir(fhir_condition) }

      let(:fhir_condition) { FHIR::Condition.new(id: '456') }

      it 'sets id correctly' do
        expect(health_condition.id).to eq('456')
      end

      it 'defaults name to nil' do
        expect(health_condition.name).to be_nil
      end

      it 'defaults date to nil' do
        expect(health_condition.date).to be_nil
      end

      it 'defaults facility to nil' do
        expect(health_condition.facility).to be_nil
      end

      it 'defaults provider to nil' do
        expect(health_condition.provider).to be_nil
      end

      it 'defaults comments to an empty array' do
        expect(health_condition.comments).to eq([])
      end
    end
  end
end
