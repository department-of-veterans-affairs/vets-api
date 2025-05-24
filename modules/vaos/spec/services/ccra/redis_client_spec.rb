# frozen_string_literal: true

require 'rails_helper'

describe Ccra::RedisClient do
  subject { described_class.new }

  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:redis_referral_expiry) { 60.minutes }
  let(:id) { '12345' }
  let(:icn) { '1234567890V123456' }

  let(:referral_data) do
    Ccra::ReferralDetail.new(
      referral_number: '12345',
      appointment_type_id: 'ov',
      referral_expiration_date: '2023-12-31',
      treating_provider_info: {
        provider_npi: '1234567890'
      },
      referral_date: '2023-01-01'
    )
  end

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear

    # Set up settings for testing
    Settings.vaos ||= OpenStruct.new
    Settings.vaos.ccra ||= OpenStruct.new
    Settings.vaos.ccra.tap do |ccra|
      ccra.redis_referral_expiry = redis_referral_expiry
    end
  end

  describe 'attributes' do
    it 'responds to settings' do
      expect(subject.respond_to?(:settings)).to be(true)
    end
  end

  describe '#save_referral_data' do
    it 'saves the referral data to cache and returns true' do
      expect(subject.save_referral_data(id:, icn:, referral_data:)).to be(true)

      # Generate the cache key in the same way as the class
      cache_key = "#{Ccra::RedisClient::REFERRAL_CACHE_KEY}#{icn}_#{id}"
      saved_data = Rails.cache.read(
        cache_key,
        namespace: Ccra::RedisClient::REFERRAL_CACHE_NAMESPACE
      )

      # Verify the data was cached - it's stored as JSON string so no need to check type
      expect(saved_data).to include('referral_number')
      expect(saved_data).to include('12345')
      expect(saved_data).to include('appointment_type_id')
      expect(saved_data).to include('ov')
    end
  end

  describe '#fetch_referral_data' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(subject.fetch_referral_data(id:, icn:)).to be_nil
      end
    end

    context 'when cache exists' do
      before do
        subject.save_referral_data(id:, icn:, referral_data:)
      end

      it 'returns the cached referral detail' do
        result = subject.fetch_referral_data(id:, icn:)
        expect(result).to be_a(Ccra::ReferralDetail)
        expect(result.referral_number).to eq('12345')
        expect(result.appointment_type_id).to eq('ov')
      end
    end

    context 'when cache has expired' do
      before do
        subject.save_referral_data(id:, icn:, referral_data:)
      end

      it 'returns nil' do
        Timecop.travel(redis_referral_expiry.from_now + 1.second) do
          expect(subject.fetch_referral_data(id:, icn:)).to be_nil
        end
      end
    end
  end

  describe '#clear_referral_data' do
    context 'when cache exists' do
      before do
        subject.save_referral_data(id:, icn:, referral_data:)
      end

      it 'clears the referral data from cache' do
        # Verify data exists before clearing
        expect(subject.fetch_referral_data(id:, icn:)).to be_a(Ccra::ReferralDetail)

        # Clear the data
        result = subject.clear_referral_data(id:, icn:)
        expect(result).to be(true)

        # Verify data no longer exists
        expect(subject.fetch_referral_data(id:, icn:)).to be_nil
      end
    end
  end
end
