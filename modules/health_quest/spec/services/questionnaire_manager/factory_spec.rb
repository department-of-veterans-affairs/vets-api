# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::Factory do
  subject { described_class }

  let(:user) { double('User', icn: '1008596379V859838') }
  let(:session_store) { double('SessionStore', token: '123abc') }
  let(:session_service) { double('HealthQuest::Lighthouse::Session', user: user, retrieve: session_store) }
  let(:client_reply) { double('FHIR::ClientReply') }

  before do
    allow(HealthQuest::Lighthouse::Session).to receive(:build).with(user).and_return(session_service)
  end

  describe 'object initialization' do
    let(:factory) { described_class.manufacture(user) }

    it 'responds to attributes' do
      expect(factory.respond_to?(:aggregated_data)).to eq(true)
      expect(factory.respond_to?(:patient)).to eq(true)
      expect(factory.respond_to?(:patient_service)).to eq(true)
      expect(factory.respond_to?(:user)).to eq(true)
    end
  end

  describe '.manufacture' do
    it 'returns an instance of the described class' do
      expect(described_class.manufacture(user)).to be_an_instance_of(described_class)
    end
  end

  describe '#all' do
    let(:patient) { double('FHIR::Patient') }

    context 'when patient does not exist' do
      let(:client_reply) { double('FHIR::ClientReply', resource: nil) }

      it 'returns a default hash' do
        hash = { data: [] }
        allow_any_instance_of(HealthQuest::PatientGeneratedData::Patient::MapQuery)
          .to receive(:get).with(user.icn).and_return(client_reply)

        expect(described_class.manufacture(user).all).to eq(hash)
      end
    end

    context 'when patient exists' do
      let(:client_reply) { double('FHIR::ClientReply', resource: patient) }

      it 'returns a WIP hash' do
        hash = { data: 'WIP' }
        allow_any_instance_of(HealthQuest::PatientGeneratedData::Patient::MapQuery)
          .to receive(:get).with(user.icn).and_return(client_reply)

        expect(described_class.manufacture(user).all).to eq(hash)
      end
    end
  end

  describe '#get_patient' do
    it 'returns a FHIR::ClientReply' do
      allow_any_instance_of(HealthQuest::PatientGeneratedData::Patient::MapQuery)
        .to receive(:get).with(user.icn).and_return(client_reply)

      expect(described_class.manufacture(user).get_patient).to eq(client_reply)
    end
  end

  describe '#compose' do
    it 'returns a WIP hash' do
      hash = { data: 'WIP' }

      expect(described_class.manufacture(user).compose).to eq(hash)
    end
  end
end
