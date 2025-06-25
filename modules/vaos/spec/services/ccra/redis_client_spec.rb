# frozen_string_literal: true

require 'rails_helper'

describe Ccra::RedisClient do
  subject { described_class.new }

  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:redis_referral_expiry) { 60.minutes }
  let(:id) { '12345' }
  let(:icn) { '1234567890V123456' }
  let(:referral_number) { 'REF123456' }
  let(:booking_start_time) { Time.current.to_f }

  let(:referral_data) do
    Ccra::ReferralDetail.new(
      referral_number:,
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

  describe '#save_booking_start_time' do
    it 'saves the booking start time to cache and returns true' do
      expect(subject.save_booking_start_time(
               referral_number:,
               booking_start_time:
             )).to be(true)

      cache_key = "#{Ccra::RedisClient::BOOKING_START_TIME_CACHE_KEY}#{referral_number}"
      saved_time = Rails.cache.read(
        cache_key,
        namespace: Ccra::RedisClient::REFERRAL_CACHE_NAMESPACE
      )

      expect(saved_time).to eq(booking_start_time)
    end

    it 'updates existing cached booking start time' do
      initial_time = Time.current.to_f
      updated_time = initial_time + 60

      subject.save_booking_start_time(
        referral_number:,
        booking_start_time: initial_time
      )

      subject.save_booking_start_time(
        referral_number:,
        booking_start_time: updated_time
      )

      cache_key = "#{Ccra::RedisClient::BOOKING_START_TIME_CACHE_KEY}#{referral_number}"
      saved_time = Rails.cache.read(
        cache_key,
        namespace: Ccra::RedisClient::REFERRAL_CACHE_NAMESPACE
      )

      expect(saved_time).to eq(updated_time)
      expect(saved_time).not_to eq(initial_time)
    end
  end

  describe '#fetch_booking_start_time' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(subject.fetch_booking_start_time(referral_number:)).to be_nil
      end
    end

    context 'when cache exists' do
      before do
        subject.save_booking_start_time(
          referral_number:,
          booking_start_time:
        )
      end

      it 'returns the cached booking start time' do
        result = subject.fetch_booking_start_time(referral_number:)
        expect(result).to eq(booking_start_time)
      end

      it 'returns nil when expired' do
        Timecop.travel(redis_referral_expiry.from_now + 1.second) do
          expect(subject.fetch_booking_start_time(referral_number:)).to be_nil
        end
      end
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

      # Parse the JSON string to verify the data
      parsed_data = JSON.parse(saved_data)
      expect(parsed_data['referral_number']).to eq(referral_number)
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
        expect(result.referral_number).to eq(referral_number)
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
