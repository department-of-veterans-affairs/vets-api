# frozen_string_literal: true

require 'rails_helper'

describe Eps::RedisClient do
  subject { described_class.new }

  let(:redis_client) { subject }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:redis_token_expiry) { 59.minutes }

  let(:referral_number) { '12345' }
  let(:npi) { '1234567890' }
  let(:appointment_type_id) { 'abc' }
  let(:start_date) { '2023-12-31' }
  let(:end_date) { '2023-12-31' }

  # Direct hash format for referral data
  let(:referral_data_hash) do
    {
      referral_number:,
      appointment_type_id:,
      end_date:,
      npi:,
      start_date:
    }
  end

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe 'attributes' do
    it 'responds to settings' do
      expect(redis_client.respond_to?(:settings)).to be(true)
    end
  end

  describe '#token' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.token).to be_nil
      end
    end

    context 'when cache exists' do
      before do
        Rails.cache.write(
          'token',
          '12345',
          namespace: 'eps-access-token',
          expires_in: redis_token_expiry
        )
      end

      it 'returns the cached value' do
        expect(redis_client.token).to eq('12345')
      end
    end

    context 'when cache has expired' do
      before do
        Rails.cache.write(
          'token',
          '67890',
          namespace: 'eps-access-token',
          expires_in: redis_token_expiry
        )
      end

      it 'returns nil' do
        Timecop.travel(redis_token_expiry.from_now) do
          expect(redis_client.token).to be_nil
        end
      end
    end
  end

  describe '#save_token' do
    let(:token) { '12345' }

    it 'saves the value in cache' do
      expect(redis_client.save_token(token:)).to be(true)

      val = Rails.cache.read(
        'token',
        namespace: 'eps-access-token'
      )
      expect(val).to eq(token)
    end
  end

  describe '#save_referral_data' do
    let(:provider_npi) { 'NPI123456' }
    let(:referral_data) do
      {
        referral_number:,
        appointment_type_id:,
        end_date:,
        npi: provider_npi,
        start_date:
      }
    end

    it 'saves the referral data to cache and returns true' do
      expect(redis_client.save_referral_data(referral_data:)).to be(true)

      saved_data = redis_client.fetch_referral_attributes(referral_number:)

      # Verify the saved data has the expected structure
      expect(saved_data).to be_a(Hash)
      expect(saved_data[:npi]).to eq(provider_npi)
      expect(saved_data[:appointment_type_id]).to eq(appointment_type_id)
      expect(saved_data[:end_date]).to eq(end_date)
      expect(saved_data[:start_date]).to eq(start_date)
      expect(saved_data[:referral_number]).to eq(referral_number)
    end
  end

  describe '#fetch_referral_attributes' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.fetch_referral_attributes(referral_number:)).to be_nil
      end
    end

    context 'when cache exists' do
      before do
        Rails.cache.write(
          "vaos_eps_referral_identifier_#{referral_number}",
          referral_data_hash,
          namespace: 'vaos-eps-cache',
          expires_in: redis_token_expiry
        )
      end

      it 'returns all cached attributes' do
        expected_attributes = referral_data_hash

        referral_attrs = redis_client.fetch_referral_attributes(referral_number:)
        expect(referral_attrs).to eq(expected_attributes)
      end
    end

    context 'when cache has expired' do
      before do
        Rails.cache.write(
          "vaos_eps_referral_identifier_#{referral_number}",
          referral_data_hash,
          namespace: 'vaos-eps-cache',
          expires_in: redis_token_expiry
        )
      end

      it 'returns nil' do
        Timecop.travel(redis_token_expiry.from_now) do
          expect(redis_client.fetch_referral_attributes(referral_number:)).to be_nil
        end
      end
    end
  end
end
