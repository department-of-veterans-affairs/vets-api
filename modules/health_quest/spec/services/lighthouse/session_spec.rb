# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Lighthouse::Session do
  subject { described_class }

  let(:user) { double('User', account_uuid: 'abc123', icn: '1008596379V859838') }

  describe 'attributes' do
    let(:session) { subject.build(user) }

    it 'responds to user' do
      expect(session.respond_to?(:user)).to be(true)
    end

    it 'responds to id' do
      expect(session.respond_to?(:id)).to be(true)
    end

    it 'responds to redis_handler' do
      expect(session.respond_to?(:redis_handler)).to be(true)
    end

    it 'responds to token' do
      expect(session.respond_to?(:token)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of Session' do
      expect(subject.build(user)).to be_an_instance_of(HealthQuest::Lighthouse::Session)
    end
  end

  describe '#retrieve' do
    let(:session_store) { double('HealthQuest::SessionStore') }

    context 'when session exists' do
      it 'returns existing session' do
        allow_any_instance_of(subject).to receive(:session_from_redis).and_return('existing_session_123')

        expect(subject.build(user).retrieve).to eq('existing_session_123')
      end
    end

    context 'when session does not exist' do
      it 'returns a new session' do
        allow_any_instance_of(subject).to receive(:session_from_redis).and_return(nil)
        allow_any_instance_of(subject).to receive(:establish_lighthouse_session).and_return(session_store)

        expect(subject.build(user).retrieve).to eq(session_store)
      end
    end
  end
end
