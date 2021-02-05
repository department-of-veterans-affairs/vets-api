# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::Factory do
  subject { described_class }

  let(:user) { double('User', icn: '1008596379V859838', account_uuid: 'abc123') }
  let(:session_store) { double('SessionStore', token: '123abc') }
  let(:session_service) { double('HealthQuest::Lighthouse::Session', user: user, retrieve: session_store) }
  let(:client_reply) { double('FHIR::ClientReply') }
  let(:default_appointments) { { data: [] } }

  before do
    allow(HealthQuest::Lighthouse::Session).to receive(:build).with(user).and_return(session_service)
  end

  describe 'object initialization' do
    let(:factory) { described_class.manufacture(user) }

    it 'responds to attributes' do
      expect(factory.respond_to?(:appointments)).to eq(true)
      expect(factory.respond_to?(:aggregated_data)).to eq(true)
      expect(factory.respond_to?(:patient)).to eq(true)
      expect(factory.respond_to?(:appointment_service)).to eq(true)
      expect(factory.respond_to?(:patient_service)).to eq(true)
      expect(factory.respond_to?(:transformer)).to eq(true)
      expect(factory.respond_to?(:user)).to eq(true)
    end
  end

  describe '.manufacture' do
    it 'returns an instance of the described class' do
      expect(described_class.manufacture(user)).to be_an_instance_of(described_class)
    end
  end

  describe '#all' do
    context 'when patient does not exist' do
      let(:client_reply) { double('FHIR::ClientReply', resource: nil) }

      before do
        allow_any_instance_of(subject).to receive(:get_patient).and_return(client_reply)
      end

      it 'returns a default hash' do
        hash = { data: [] }

        expect(described_class.manufacture(user).all).to eq(hash)
      end

      it 'has a nil patient' do
        factory = described_class.manufacture(user)
        factory.all

        expect(factory.patient).to be_nil
      end
    end

    context 'when patient and no appointments' do
      let(:fhir_patient) { double('FHIR::Patient') }
      let(:client_reply) { double('FHIR::ClientReply', resource: fhir_patient) }

      before do
        allow_any_instance_of(subject).to receive(:get_appointments).and_return(default_appointments)
        allow_any_instance_of(subject).to receive(:get_patient).and_return(client_reply)
      end

      it 'returns a default hash' do
        hash = { data: [] }

        expect(described_class.manufacture(user).all).to eq(hash)
      end

      it 'has a FHIR::Patient patient' do
        factory = described_class.manufacture(user)
        factory.all

        expect(factory.patient).to eq(fhir_patient)
      end
    end

    context 'when patient and appointments and no questionnaires' do
      let(:appointments) { { data: [{}, {}] } }
      let(:fhir_patient) { double('FHIR::Patient') }
      let(:client_reply) { double('FHIR::ClientReply', resource: fhir_patient) }
      let(:questionnaire_client_reply) { double('FHIR::ClientReply', resource: double('FHIR::ClientReply', entry: [])) }

      before do
        allow_any_instance_of(subject).to receive(:get_appointments).and_return(appointments)
        allow_any_instance_of(subject).to receive(:get_patient).and_return(client_reply)
        allow_any_instance_of(subject).to receive(:get_questionnaires).and_return(questionnaire_client_reply)
      end

      it 'returns a default hash' do
        hash = { data: [] }

        expect(described_class.manufacture(user).all).to eq(hash)
      end

      it 'has a FHIR::Patient patient' do
        factory = described_class.manufacture(user)
        factory.all

        expect(factory.patient).to eq(fhir_patient)
      end
    end

    context 'when patient and appointment and questionnaires exist' do
      let(:appointments) { { data: [{}, {}] } }
      let(:fhir_patient) { double('FHIR::Patient') }
      let(:fhir_questionnaire_bundle) { double('FHIR::Bundle', entry: [{}, {}]) }
      let(:client_reply) { double('FHIR::ClientReply', resource: fhir_patient) }
      let(:questionnaire_client_reply) { double('FHIR::ClientReply', resource: fhir_questionnaire_bundle) }

      before do
        allow_any_instance_of(subject).to receive(:get_appointments).and_return(appointments)
        allow_any_instance_of(subject).to receive(:get_patient).and_return(client_reply)
        allow_any_instance_of(subject).to receive(:get_questionnaires).and_return(questionnaire_client_reply)
      end

      it 'returns a WIP hash' do
        hash = { data: 'WIP' }

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
