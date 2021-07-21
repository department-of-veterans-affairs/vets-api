# frozen_string_literal: true

require 'rails_helper'

describe ChipApi::Session do
  subject { described_class }

  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe 'attributes' do
    it 'responds to redis_handler' do
      expect(subject.build.respond_to?(:redis_handler)).to be(true)
    end

    it 'responds to token' do
      expect(subject.build.respond_to?(:token)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of Session' do
      expect(subject.build).to be_an_instance_of(ChipApi::Session)
    end
  end

  describe '#retrieve' do
    context 'when cache exists' do
      it 'returns existing session' do
        allow_any_instance_of(subject).to receive(:session_from_redis).and_return('existing_session_123')

        expect(subject.build.retrieve).to eq('existing_session_123')
      end
    end

    context 'when cache does not exist' do
      it 'returns a new session' do
        allow_any_instance_of(subject).to receive(:session_from_redis).and_return(nil)
        allow_any_instance_of(subject).to receive(:establish_chip_session).and_return('new_session_123')

        expect(subject.build.retrieve).to eq('new_session_123')
      end
    end
  end

  describe '#session_from_redis' do
    context 'when cache exists' do
      it 'returns an instance of SessionStore' do
        allow_any_instance_of(ChipApi::RedisHandler).to receive(:session_id).and_return('my_session_id')

        Rails.cache.write('my_session_id', '12345', namespace: 'check-in-cache')

        expect(subject.build.session_from_redis).to eq('12345')
      end
    end

    context 'when cache does not exist' do
      it 'returns nil' do
        allow_any_instance_of(ChipApi::RedisHandler).to receive(:session_id).and_return(nil)

        expect(subject.build.session_from_redis).to eq(nil)
      end
    end
  end

  describe '#establish_chip_session' do
    let(:mock_token) { double('ChipApi::Token', access_token: 'new_chip_token', created_at: Time.zone.now) }

    it 'returns token from cache' do
      allow_any_instance_of(ChipApi::Token).to receive(:fetch).and_return(mock_token)
      allow_any_instance_of(subject).to receive(:session_id).and_return('my_session_id')

      expect(subject.build.establish_chip_session).to eq('new_chip_token')
    end
  end

  describe '#session_id' do
    it 'returns the formatted session_id' do
      expect(subject.build.session_id).to eq('check_in_2dcdrrn5zc')
    end
  end
end
