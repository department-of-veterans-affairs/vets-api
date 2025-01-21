# frozen_string_literal: true

require 'rails_helper'

describe V2::Chip::RedisClient do
  subject { described_class }

  let(:opts) do
    {
      data: {
        uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
        last4: '1234',
        last_name: 'Johnson'
      },
      jwt: nil
    }
  end
  let(:check_in) { CheckIn::V2::Session.build(opts) }
  let(:redis_client) { subject.build }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:redis_expiry_time) { 14.minutes }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe 'attributes' do
    it 'responds to settings' do
      expect(redis_client.respond_to?(:settings)).to be(true)
    end

    it 'gets redis_session_prefix from settings' do
      expect(redis_client.redis_session_prefix).to eq('check_in_chip_v2')
    end

    it 'gets tmp_api_id from settings' do
      expect(redis_client.tmp_api_id).to eq('2dcdrrn5zc')
    end
  end

  describe '.build' do
    it 'returns an instance of RedisClient' do
      expect(redis_client).to be_an_instance_of(V2::Chip::RedisClient)
    end
  end

  describe '#get' do
    context 'when cache exists' do
      before do
        Rails.cache.write(
          'check_in_chip_v2_2dcdrrn5zc',
          '12345',
          namespace: 'check-in-chip-v2-cache',
          expires_in: redis_expiry_time
        )
      end

      it 'returns the cached value' do
        expect(redis_client.get).to eq('12345')
      end
    end

    context 'when cache expires' do
      before do
        Rails.cache.write(
          'check_in_chip_v2_2dcdrrn5zc',
          '52617',
          namespace: 'check-in-chip-v2-cache',
          expires_in: redis_expiry_time
        )
      end

      it 'returns nil' do
        Timecop.travel(redis_expiry_time.from_now) do
          expect(redis_client.get).to be_nil
        end
      end
    end

    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.get).to be_nil
      end
    end
  end

  describe '#save' do
    let(:token) { '12345' }

    it 'saves the value in cache' do
      expect(redis_client.save(token:)).to be(true)

      val = Rails.cache.read(
        'check_in_chip_v2_2dcdrrn5zc',
        namespace: 'check-in-chip-v2-cache'
      )
      expect(val).to eq(token)
    end
  end
end
