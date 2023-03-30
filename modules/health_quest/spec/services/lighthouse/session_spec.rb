# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Lighthouse::Session do
  subject { described_class }

  let(:user) { double('User', account_uuid: 'abc123', icn: '1008596379V859838') }

  describe 'attributes' do
    let(:session) { subject.build(user:, api: 'pgd_api') }

    it 'responds to api' do
      expect(session.respond_to?(:api)).to be(true)
    end

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
      expect(subject.build(user:, api: 'pgd_api')).to be_an_instance_of(HealthQuest::Lighthouse::Session)
    end
  end

  describe '#retrieve' do
    let(:session_store) { double('HealthQuest::SessionStore') }

    context 'when session exists' do
      it 'returns existing session' do
        allow_any_instance_of(subject).to receive(:session_from_redis).and_return('existing_session_123')

        expect(subject.build(user:, api: 'pgd_api').retrieve).to eq('existing_session_123')
      end
    end

    context 'when session does not exist' do
      it 'returns a new session' do
        allow_any_instance_of(subject).to receive(:session_from_redis).and_return(nil)
        allow_any_instance_of(subject).to receive(:establish_lighthouse_session).and_return(session_store)

        expect(subject.build(user:, api: 'pgd_api').retrieve).to eq(session_store)
      end
    end
  end

  describe '#session_from_redis' do
    let(:session_store) { double('HealthQuest::SessionStore') }

    context 'when session exists' do
      it 'returns an instance of SessionStore' do
        allow(HealthQuest::SessionStore).to receive(:find).with(anything).and_return(session_store)

        expect(subject.build(user:, api: 'pgd_api').session_from_redis).to eq(session_store)
      end
    end

    context 'when session does not exist' do
      it 'returns nil' do
        allow(HealthQuest::SessionStore).to receive(:find).with(anything).and_return(nil)

        expect(subject.build(user:, api: 'pgd_api').session_from_redis).to eq(nil)
      end
    end
  end

  describe '#lighthouse_access_token' do
    let(:token) { HealthQuest::Lighthouse::Token.build(user:, api: 'pgd_api') }

    it 'returns a Token instance' do
      allow_any_instance_of(HealthQuest::Lighthouse::Token).to receive(:fetch).and_return(token)

      expect(subject.build(user:, api: 'pgd_api').lighthouse_access_token).to eq(token)
    end
  end

  describe '#establish_lighthouse_session' do
    let(:token) { double('Token', access_token: '123', decoded_token: '34568', created_at: 1234, ttl_duration: 5647) }

    it 'returns a session store' do
      allow_any_instance_of(subject).to receive(:lighthouse_access_token).and_return(token)

      expect(subject.build(user:, api: 'pgd_api').establish_lighthouse_session).to be_a(HealthQuest::SessionStore)
    end
  end

  describe '#session_id' do
    context 'when pgd_api' do
      it 'builds a pgd session_id' do
        pgd_session_id = 'healthquest_lighthouse_pgd_api_abc123'

        expect(subject.build(user:, api: 'pgd_api').session_id).to eq(pgd_session_id)
      end
    end

    context 'when health_api' do
      it 'builds a health session_id' do
        health_session_id = 'healthquest_lighthouse_health_api_abc123'

        expect(subject.build(user:, api: 'health_api').session_id).to eq(health_session_id)
      end
    end
  end
end
