# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::Factory do
  subject { described_class }

  let(:user) { double('User', icn: '1008596379V859838', account_uuid: 'abc123', uuid: '789defg') }
  let(:session_store) { double('SessionStore', token: '123abc') }
  let(:session_service) { double('HealthQuest::Lighthouse::Session', user: user, retrieve: session_store) }
  let(:client_reply) { double('FHIR::ClientReply') }
  let(:default_appointments) { { data: [] } }
  let(:appointments) { { data: [{}, {}] } }

  before do
    allow(HealthQuest::Lighthouse::Session).to receive(:build).with(user).and_return(session_service)
  end

  describe 'object initialization' do
    let(:factory) { described_class.manufacture(user) }

    it 'responds to attributes' do
      expect(factory.respond_to?(:appointments)).to eq(true)
      expect(factory.respond_to?(:aggregated_data)).to eq(true)
      expect(factory.respond_to?(:patient)).to eq(true)
      expect(factory.respond_to?(:questionnaires)).to eq(true)
      expect(factory.respond_to?(:save_in_progress)).to eq(true)
      expect(factory.respond_to?(:appointment_service)).to eq(true)
      expect(factory.respond_to?(:patient_service)).to eq(true)
      expect(factory.respond_to?(:questionnaire_service)).to eq(true)
      expect(factory.respond_to?(:sip_model)).to eq(true)
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
    let(:fhir_data) { double('FHIR::Bundle', entry: [{}, {}]) }
    let(:questionnaire_response_client_reply) do
      double('FHIR::ClientReply', resource: fhir_questionnaire_response_bundle)
    end
    let(:fhir_questionnaire_response_bundle) { fhir_data }
    let(:questionnaire_client_reply) { double('FHIR::ClientReply', resource: fhir_questionnaire_bundle) }

    before do
      allow_any_instance_of(subject).to receive(:get_patient).and_return(client_reply)
      allow_any_instance_of(subject).to receive(:get_appointments).and_return(appointments)
      allow_any_instance_of(subject).to receive(:get_save_in_progress).and_return([{}])
      allow_any_instance_of(subject)
        .to receive(:get_questionnaire_responses).and_return(questionnaire_response_client_reply)
      allow_any_instance_of(subject).to receive(:get_questionnaires).and_return(questionnaire_client_reply)
    end

    context 'when appointment does not exist' do
      let(:questionnaire_response_client_reply) { nil }
      let(:questionnaire_client_reply) { nil }
      let(:fhir_questionnaire_response_bundle) { nil }

      before do
        allow_any_instance_of(subject).to receive(:get_appointments).and_return(default_appointments)
      end

      it 'returns a default hash' do
        hash = { data: [] }

        expect(described_class.manufacture(user).all).to eq(hash)
      end
    end

    context 'when appointments and questionnaires and questionnaire_responses and sip and no patient' do
      let(:client_reply) { double('FHIR::ClientReply', resource: nil) }
      let(:fhir_questionnaire_bundle) { fhir_data }

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

    context 'when appointments and patient and questionnaire_responses and sip and no questionnaires' do
      let(:fhir_patient) { double('FHIR::Patient') }
      let(:client_reply) { double('FHIR::ClientReply', resource: fhir_patient) }
      let(:questionnaire_client_reply) { double('FHIR::ClientReply', resource: double('FHIR::ClientReply', entry: [])) }

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

    context 'when patient and appointment and questionnaires and questionnaire_responses and sip data exist' do
      let(:fhir_patient) { double('FHIR::Patient') }
      let(:client_reply) { double('FHIR::ClientReply', resource: fhir_patient) }
      let(:fhir_questionnaire_bundle) { fhir_data }

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

  describe '#get_questionnaires' do
    let(:client_reply) { double('FHIR::ClientReply', resource: double('FHIR::Bundle', entry: [{}])) }

    it 'returns a FHIR::ClientReply' do
      allow_any_instance_of(HealthQuest::PatientGeneratedData::Questionnaire::MapQuery)
        .to receive(:search).with(anything).and_return(client_reply)
      allow_any_instance_of(HealthQuest::QuestionnaireManager::Transformer)
        .to receive(:get_use_context).with(anything).and_return('venue$583/12345')

      expect(described_class.manufacture(user).get_questionnaires).to eq(client_reply)
    end
  end

  describe '#get_questionnaire_responses' do
    let(:client_reply) { double('FHIR::ClientReply', resource: double('FHIR::Bundle', entry: [{}])) }

    it 'returns a FHIR::ClientReply' do
      allow_any_instance_of(HealthQuest::PatientGeneratedData::QuestionnaireResponse::MapQuery)
        .to receive(:search).with(anything).and_return(client_reply)

      expect(described_class.manufacture(user).get_questionnaire_responses).to eq(client_reply)
    end
  end

  describe '#get_appointments' do
    it 'returns a FHIR::ClientReply' do
      allow_any_instance_of(HealthQuest::AppointmentService).to receive(:get_appointments).and_return(appointments)

      expect(described_class.manufacture(user).get_appointments).to eq(appointments)
    end
  end

  describe '#get_save_in_progress' do
    it 'returns an empty array when user does not exist' do
      expect(described_class.manufacture(user).get_save_in_progress).to eq([])
    end
  end

  describe '#compose' do
    it 'returns a WIP hash' do
      hash = { data: 'WIP' }

      expect(described_class.manufacture(user).compose).to eq(hash)
    end
  end
end
