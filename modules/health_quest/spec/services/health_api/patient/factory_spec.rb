# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::HealthApi::Patient::Factory do
  subject { described_class }

  let(:user) { double('User', icn: '1008596379V859838') }
  let(:session_store) { double('SessionStore', token: '123abc') }
  let(:session_service) do
    double('HealthQuest::Lighthouse::Session', user: user, api: 'pgd_api', retrieve: session_store)
  end
  let(:client_reply) { double('FHIR::ClientReply') }

  before do
    allow(HealthQuest::Lighthouse::Session).to receive(:build).and_return(session_service)
  end

  describe '#get' do
    it 'returns a ClientReply' do
      allow_any_instance_of(HealthQuest::HealthApi::Patient::MapQuery)
        .to receive(:get).with(user.icn).and_return(client_reply)

      expect(subject.new(user).get).to eq(client_reply)
    end
  end

  describe '#create' do
    it 'returns a ClientReply' do
      allow_any_instance_of(HealthQuest::HealthApi::Patient::MapQuery)
        .to receive(:create).with(user).and_return(client_reply)

      expect(subject.new(user).create).to eq(client_reply)
    end
  end
end
