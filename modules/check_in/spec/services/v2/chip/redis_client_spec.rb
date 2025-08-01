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

  describe 'feature flag behavior' do
    context 'when check_in_experience_use_vaec_cie_endpoints flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with('check_in_experience_use_vaec_cie_endpoints').and_return(false)
      end

      it 'uses original tmp_api_id for session_id' do
        expect(redis_client.send(:tmp_api_id)).to eq(Settings.check_in.chip_api_v2.tmp_api_id)
        expect(redis_client.session_id).to eq('check_in_chip_v2_2dcdrrn5zc')
      end

      it 'stores and retrieves data with original session_id' do
        token = 'test_token_123'
        redis_client.save(token:)
        expect(redis_client.get).to eq(token)
      end
    end

    context 'when check_in_experience_use_vaec_cie_endpoints flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with('check_in_experience_use_vaec_cie_endpoints').and_return(true)
      end

      it 'uses v2 tmp_api_id for session_id' do
        expect(redis_client.send(:tmp_api_id)).to eq(Settings.check_in.chip_api_v2.tmp_api_id_v2)
        # Since test.yml has the same value for both, session_id will be the same
        expect(redis_client.session_id).to eq('check_in_chip_v2_2dcdrrn5zc')
      end

      it 'stores and retrieves data with v2 session_id' do
        token = 'test_token_v2_456'
        redis_client.save(token:)
        expect(redis_client.get).to eq(token)
      end

      it 'uses different cache key when v2 api_id is different' do
        # This test demonstrates that if the v2 api_id were different,
        # it would use a different cache key
        allow(Settings.check_in.chip_api_v2).to receive(:tmp_api_id_v2).and_return('different_api_id')
        expect(redis_client.session_id).to eq('check_in_chip_v2_different_api_id')
      end
    end
  end
end
