# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Lighthouse::RedisHandler do
  subject { described_class }

  let(:session_store) { double('HealthQuest::SessionStore') }
  let(:redis_handler) { subject.build(session_id: '123', session_store: HealthQuest::SessionStore) }
  let(:token) { double('Token', access_token: '123', created_at: 1234, ttl_duration: 5647) }

  describe 'attributes' do
    it 'responds to session_id' do
      expect(redis_handler.respond_to?(:session_id)).to be(true)
    end

    it 'responds to session_store' do
      expect(redis_handler.respond_to?(:session_store)).to be(true)
    end

    it 'responds to token' do
      expect(redis_handler.respond_to?(:token)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of RedisHandler' do
      expect(subject.build).to be_an_instance_of(HealthQuest::Lighthouse::RedisHandler)
    end
  end

  describe '#get' do
    context 'when session exists' do
      it 'returns an instance of SessionStore' do
        allow(HealthQuest::SessionStore).to receive(:find).with(anything).and_return(session_store)

        expect(subject.build.get).to eq(session_store)
      end
    end

    context 'when session does not exist' do
      it 'returns nil' do
        allow(HealthQuest::SessionStore).to receive(:find).with(anything).and_return(nil)

        expect(subject.build.get).to be_nil
      end
    end
  end

  describe '#save' do
    it 'saves and returns a SessionStore' do
      redis_handler.token = token

      expect(redis_handler.save).to be_an_instance_of(HealthQuest::SessionStore)
    end
  end
end
