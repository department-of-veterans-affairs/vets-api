# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::PatientGeneratedData::QuestionnaireResponse::Factory do
  subject { described_class }

  let(:headers) { { 'Accept' => 'application/json+fhir' } }
  let(:user) { double('User', icn: '1008596379V859838') }
  let(:session_service) { double('HealthQuest::SessionService', user: user, headers: headers) }
  let(:client_reply) { double('FHIR::ClientReply') }

  before do
    allow(HealthQuest::SessionService).to receive(:new).with(user).and_return(session_service)
  end

  describe 'object initialization' do
    let(:factory) { described_class.manufacture(user) }

    it 'responds to attributes' do
      expect(factory.respond_to?(:session_service)).to eq(true)
      expect(factory.respond_to?(:user)).to eq(true)
      expect(factory.respond_to?(:map_query)).to eq(true)
    end
  end

  describe '.manufacture' do
    it 'returns an instance of the described class' do
      expect(described_class.manufacture(user)).to be_an_instance_of(described_class)
    end
  end

  describe '#search' do
    let(:filters) { { appointment_id: nil }.with_indifferent_access }
    let(:options_builder) { HealthQuest::PatientGeneratedData::OptionsBuilder.manufacture(user, filters) }

    it 'returns a ClientReply' do
      allow_any_instance_of(FHIR::Client).to receive(:search).with(anything, anything).and_return(client_reply)

      expect(subject.new(user).search(options_builder.to_hash)).to eq(client_reply)
    end
  end

  describe '#get' do
    let(:id) { 'faae134c-9c7b-49d7-8161-10e314da4de1' }

    it 'returns a ClientReply' do
      allow_any_instance_of(HealthQuest::PatientGeneratedData::QuestionnaireResponse::MapQuery)
        .to receive(:get).with(id).and_return(client_reply)

      expect(subject.new(user).get(id)).to eq(client_reply)
    end
  end

  describe '#create' do
    let(:data) do
      {
        appointment_id: 'abc123',
        questionnaire_response: {},
        questionnaire_id: 'abcd-1234'
      }
    end

    it 'returns a ClientReply' do
      allow_any_instance_of(HealthQuest::PatientGeneratedData::QuestionnaireResponse::MapQuery)
        .to receive(:create).with(anything).and_return(client_reply)

      expect(subject.new(user).create(data)).to eq(client_reply)
    end
  end
end
