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
    allow_any_instance_of(HealthQuest::PatientGeneratedData::QuestionnaireResponse::MapQuery)
      .to receive(:search).with({ author: user.icn }).and_return(client_reply)
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
    it 'returns a ClientReply' do
      expect(subject.new(user).search).to eq(client_reply)
    end
  end
end
