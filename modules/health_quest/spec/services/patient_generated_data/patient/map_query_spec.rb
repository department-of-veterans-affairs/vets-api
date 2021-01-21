# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::PatientGeneratedData::Patient::MapQuery do
  subject { described_class }

  let(:headers) { { 'Accept' => 'application/json+fhir' } }

  describe 'included modules' do
    it 'includes PatientGeneratedData::FHIRClient' do
      expect(subject.ancestors).to include(HealthQuest::PatientGeneratedData::FHIRClient)
    end
  end

  describe '.build' do
    it 'returns an instance of MapQuery' do
      expect(subject.build(headers)).to be_an_instance_of(subject)
    end
  end

  describe 'object initialization' do
    it 'has a headers attribute' do
      expect(subject.new({}).respond_to?(:headers)).to eq(true)
    end
  end

  describe '#fhir_model' do
    it 'is a FHIR::Patient class' do
      expect(subject.new({}).fhir_model).to eq(FHIR::Patient)
    end
  end

  describe '#get' do
    context 'with valid id' do
      let(:client) { double('HealthQuest::PatientGeneratedData::FHIRClient') }

      before do
        allow_any_instance_of(subject).to receive(:client).and_return(client)
      end

      it 'returns an instance of Reply' do
        expect(client).to receive(:read).with(FHIR::Patient, '123').exactly(1).time

        subject.build(headers).get('123')
      end
    end
  end

  describe '#create' do
    let(:client) { double('HealthQuest::PatientGeneratedData::FHIRClient') }
    let(:user) { double('User', icn: '1008596379V859838', first_name: 'Bob', last_name: 'Smith') }
    let(:patient) { HealthQuest::PatientGeneratedData::Patient::Resource.manufacture(user).prepare }

    before do
      allow_any_instance_of(subject).to receive(:client).and_return(client)
    end

    it 'returns an instance of Reply' do
      expect(client).to receive(:create).with(patient).exactly(1).time

      subject.build(headers).create(user)
    end
  end
end
