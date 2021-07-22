# frozen_string_literal: true

require 'rails_helper'

describe ChipApi::RedisHandler do
  subject { described_class }

  let(:redis_handler) { subject.build(session_id: '123') }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe 'attributes' do
    it 'responds to session_id' do
      expect(redis_handler.respond_to?(:session_id)).to be(true)
    end

    it 'responds to token' do
      expect(redis_handler.respond_to?(:token)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of RedisHandler' do
      expect(subject.build).to be_an_instance_of(ChipApi::RedisHandler)
    end
  end

  describe '#get' do
    context 'when cache exists' do
      it 'returns the cached value' do
        allow_any_instance_of(subject).to receive(:session_id).and_return('my_session_id')

        Rails.cache.write('my_session_id', '12345', namespace: 'check-in-cache')

        expect(subject.build.get).to eq('12345')
      end
    end

    context 'when cache does not exist' do
      it 'returns nil' do
        allow_any_instance_of(subject).to receive(:session_id).and_return('my_session_id')

        expect(subject.build.get).to eq(nil)
      end
    end
  end

  describe '#save' do
    it 'is true' do
      allow_any_instance_of(subject).to receive(:session_id).and_return('my_session_id')
      allow_any_instance_of(ChipApi::Token).to receive(:access_token).and_return('my_token')
      allow_any_instance_of(ChipApi::Token).to receive(:created_at).and_return('my_time')
      allow_any_instance_of(subject).to receive(:token).and_return(ChipApi::Token.build)

      expect(subject.build.save).to eq(true)
    end
  end
end
