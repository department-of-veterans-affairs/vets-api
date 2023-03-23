# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Resource::Factory do
  include HealthQuest::QuestionnaireManager::FactoryTypes

  subject { described_class }

  let(:user) { double('User', icn: '1008596379V859838') }
  let(:session_store) { double('SessionStore', token: '123abc') }
  let(:session_service) do
    double('HealthQuest::Lighthouse::Session', user:, api: 'pgd_api', retrieve: session_store)
  end
  let(:client_reply) { double('FHIR::ClientReply') }

  before do
    allow(HealthQuest::Lighthouse::Session).to receive(:build).and_return(session_service)
  end

  describe 'object initialization' do
    let(:factory) { described_class.manufacture(questionnaire_type) }

    it 'responds to attributes' do
      expect(factory.respond_to?(:session_service)).to eq(true)
      expect(factory.respond_to?(:user)).to eq(true)
      expect(factory.respond_to?(:query)).to eq(true)
      expect(factory.respond_to?(:resource_identifier)).to eq(true)
      expect(factory.respond_to?(:options_builder)).to eq(true)
    end
  end

  describe '.manufacture' do
    it 'returns an instance of the described class' do
      expect(described_class.manufacture(questionnaire_response_type)).to be_an_instance_of(described_class)
    end
  end

  describe '#search' do
    let(:filters) { { resource_name: 'questionnaire_response', appointment_id: nil }.with_indifferent_access }
    let(:options_builder) { HealthQuest::Shared::OptionsBuilder.manufacture(user, filters) }

    it 'returns a ClientReply' do
      allow_any_instance_of(FHIR::Client).to receive(:search).with(anything, anything).and_return(client_reply)

      expect(subject.new(questionnaire_response_type).search(options_builder.to_hash)).to eq(client_reply)
    end
  end

  describe '#get' do
    let(:id) { '123abc' }

    it 'returns a ClientReply' do
      allow_any_instance_of(described_class).to receive(:get).with(id).and_return(client_reply)

      expect(subject.new(patient_type).get(id)).to eq(client_reply)
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
      allow_any_instance_of(described_class).to receive(:create).with(anything).and_return(client_reply)

      expect(subject.new(questionnaire_response_type).create(data)).to eq(client_reply)
    end
  end
end
