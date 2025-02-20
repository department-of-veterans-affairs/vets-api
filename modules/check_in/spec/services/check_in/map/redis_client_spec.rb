# frozen_string_literal: true

require 'rails_helper'

describe CheckIn::Map::RedisClient do
  subject { described_class }

  let(:redis_client) { subject.build }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:expires_in) { 5.minutes }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe '.build' do
    it 'returns an instance of RedisClient' do
      expect(redis_client).to be_an_instance_of(CheckIn::Map::RedisClient)
    end
  end

  describe '#token' do
    let(:token) { 'some_value' }
    let(:patient_icn) { '12345' }

    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.token(patient_icn: '123')).to be_nil
      end
    end

    context 'when cache exists' do
      before do
        Rails.cache.write(
          patient_icn,
          token,
          namespace: 'check-in-map-token-cache',
          expires_in:
        )
      end

      it 'returns the cached value' do
        expect(redis_client.token(patient_icn:)).to eq(token)
      end
    end

    context 'when cache has expired' do
      before do
        Rails.cache.write(
          patient_icn,
          token,
          namespace: 'check-in-map-token-cache',
          expires_in:
        )
      end

      it 'returns nil' do
        Timecop.travel(expires_in.from_now) do
          expect(redis_client.token(patient_icn:)).to be_nil
        end
      end
    end
  end

  describe '#save_token' do
    let(:token) { 'some_value' }
    let(:patient_icn) { '12345' }

    it 'saves the value in cache' do
      expect(
        redis_client.save_token(patient_icn:, token:, expires_in:)
      ).to be(true)

      val = Rails.cache.read(
        patient_icn,
        namespace: 'check-in-map-token-cache'
      )
      expect(val).to eq(token)
    end
  end
end
