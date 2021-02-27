# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::HealthApi::Appointment::Factory do
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

  describe '#resource_name' do
    it 'returns the resource name hash' do
      expect(described_class.manufacture(user).resource_name).to eq({ resource_name: 'appointment' })
    end
  end

  describe '#search' do
    let(:filters) { { resource_name: 'appointment', patient: user.icn }.with_indifferent_access }
    let(:options_builder) { HealthQuest::Shared::OptionsBuilder.manufacture(user, filters) }

    it 'returns a ClientReply' do
      allow_any_instance_of(FHIR::Client).to receive(:search).with(anything, anything).and_return(client_reply)

      expect(described_class.manufacture(user).search(options_builder.to_hash)).to eq(client_reply)
    end
  end

  describe '#get' do
    let(:id) { 'I2-ABC1234' }

    it 'returns a ClientReply' do
      allow_any_instance_of(HealthQuest::HealthApi::Appointment::MapQuery)
        .to receive(:get).with(id).and_return(client_reply)

      expect(described_class.manufacture(user).get(id)).to eq(client_reply)
    end
  end
end
