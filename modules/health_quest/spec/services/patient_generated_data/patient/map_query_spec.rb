# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::PatientGeneratedData::Patient::MapQuery do
  subject { described_class }

  let(:session_store) { double('SessionStore', token: '123abc') }

  describe 'included modules' do
    it 'includes PatientGeneratedData::FHIRClient' do
      expect(subject.ancestors).to include(HealthQuest::PatientGeneratedData::FHIRClient)
    end

    it 'includes PatientGeneratedData::FHIRHeaders' do
      expect(subject.ancestors).to include(HealthQuest::PatientGeneratedData::FHIRHeaders)
    end
  end

  describe '.build' do
    it 'returns an instance of MapQuery' do
      expect(subject.build(session_store)).to be_an_instance_of(subject)
    end
  end

  describe 'object initialization' do
    it 'has a headers attribute' do
      expect(subject.new(session_store).respond_to?(:headers)).to eq(true)
    end
  end

  describe '#fhir_model' do
    it 'is a FHIR::Patient class' do
      expect(subject.new(session_store).fhir_model).to eq(FHIR::Patient)
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

        subject.build(session_store).get('123')
      end

      it 'has request headers' do
        allow(client).to receive(:read).with(FHIR::Patient, '123').and_return(anything)

        map_query = subject.build(session_store)
        map_query.get('123')

        expect(map_query.headers).to eq({ 'Authorization' => 'Bearer 123abc' })
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

      subject.build(session_store).create(user)
    end

    it 'has request headers' do
      request_headers =
        { 'Authorization' => 'Bearer 123abc', 'Content-Type' => 'application/fhir+json' }

      allow(client).to receive(:create).with(patient).and_return(anything)

      map_query = subject.build(session_store)
      map_query.create(user)

      expect(map_query.headers).to eq(request_headers)
    end
  end
end
