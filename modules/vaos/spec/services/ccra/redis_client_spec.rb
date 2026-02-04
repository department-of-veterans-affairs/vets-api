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
    it 'saves encrypted referral data to cache and returns true' do
      expect(subject.save_referral_data(id:, icn:, referral_data:)).to be(true)

      # Generate the cache key with hashed ICN
      hashed_icn = Digest::SHA256.hexdigest(icn)
      cache_key = "#{Ccra::RedisClient::REFERRAL_CACHE_KEY}#{hashed_icn}_#{id}"
      saved_data = Rails.cache.read(
        cache_key,
        namespace: Ccra::RedisClient::REFERRAL_CACHE_NAMESPACE
      )

      # Verify data is encrypted (should be a string, not contain plaintext)
      expect(saved_data).to be_present
      expect(saved_data).to be_a(String)
      expect(saved_data).not_to include(referral_number) # Should not contain plaintext referral number
      expect(saved_data).not_to include(icn) # Should not contain plaintext ICN
    end

    it 'encrypts data before storing' do
      lockbox_instance = subject.send(:lockbox)
      expect(lockbox_instance).to receive(:encrypt).and_call_original

      subject.save_referral_data(id:, icn:, referral_data:)
    end

    it 'uses hashed ICN in cache key' do
      subject.save_referral_data(id:, icn:, referral_data:)

      # Cache key should use hashed ICN, not plaintext
      hashed_icn = Digest::SHA256.hexdigest(icn)
      expected_key = "#{Ccra::RedisClient::REFERRAL_CACHE_KEY}#{hashed_icn}_#{id}"

      cached_data = Rails.cache.read(
        expected_key,
        namespace: Ccra::RedisClient::REFERRAL_CACHE_NAMESPACE
      )
      expect(cached_data).to be_present

      # Verify plaintext ICN key does NOT exist
      plaintext_key = "#{Ccra::RedisClient::REFERRAL_CACHE_KEY}#{icn}_#{id}"
      plaintext_data = Rails.cache.read(
        plaintext_key,
        namespace: Ccra::RedisClient::REFERRAL_CACHE_NAMESPACE
      )
      expect(plaintext_data).to be_nil
    end
  end

  describe '#fetch_referral_data' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(subject.fetch_referral_data(id:, icn:)).to be_nil
      end
    end

    context 'when encrypted cache exists' do
      before do
        subject.save_referral_data(id:, icn:, referral_data:)
      end

      it 'retrieves and decrypts the cached referral detail' do
        result = subject.fetch_referral_data(id:, icn:)
        expect(result).to be_a(Ccra::ReferralDetail)
        expect(result.referral_number).to eq(referral_number)
      end

      it 'decrypts data after retrieval' do
        lockbox_instance = subject.send(:lockbox)
        expect(lockbox_instance).to receive(:decrypt).and_call_original

        subject.fetch_referral_data(id:, icn:)
      end
    end

    context 'with invalid encrypted data' do
      before do
        # Store invalid encrypted data using hashed ICN key
        hashed_icn = Digest::SHA256.hexdigest(icn)
        cache_key = "#{Ccra::RedisClient::REFERRAL_CACHE_KEY}#{hashed_icn}_#{id}"
        Rails.cache.write(
          cache_key,
          'invalid-encrypted-data',
          namespace: Ccra::RedisClient::REFERRAL_CACHE_NAMESPACE
        )
      end

      it 'returns nil and logs warning when decryption fails' do
        expect(Rails.logger).to receive(:warn).with(/Failed to decrypt cached data/)

        result = subject.fetch_referral_data(id:, icn:)
        expect(result).to be_nil
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

  describe 'encryption round-trip' do
    it 'successfully encrypts and decrypts referral data' do
      subject.save_referral_data(id:, icn:, referral_data:)
      result = subject.fetch_referral_data(id:, icn:)

      expect(result).to be_a(Ccra::ReferralDetail)
      expect(result.referral_number).to eq(referral_number)
    end

    it 'maintains referral data integrity through encryption' do
      subject.save_referral_data(id:, icn:, referral_data:)
      result = subject.fetch_referral_data(id:, icn:)

      expect(result.referral_number).to eq(referral_data.referral_number)
      expect(result.referral_date).to eq(referral_data.referral_date)
      expect(result.expiration_date).to eq(referral_data.expiration_date)
    end
  end

  describe '#generate_cache_key' do
    it 'generates key with hashed ICN' do
      cache_key = subject.send(:generate_cache_key, id, icn)
      hashed_icn = Digest::SHA256.hexdigest(icn)

      expect(cache_key).to eq("#{Ccra::RedisClient::REFERRAL_CACHE_KEY}#{hashed_icn}_#{id}")
      expect(cache_key).not_to include(icn) # Should not contain plaintext ICN
    end

    it 'generates consistent keys for same ICN' do
      key1 = subject.send(:generate_cache_key, id, icn)
      key2 = subject.send(:generate_cache_key, id, icn)

      expect(key1).to eq(key2)
    end

    it 'generates different keys for different ICNs' do
      icn2 = '9876543210V654321'
      key1 = subject.send(:generate_cache_key, id, icn)
      key2 = subject.send(:generate_cache_key, id, icn2)

      expect(key1).not_to eq(key2)
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

  describe '#lockbox' do
    context 'when Settings.lockbox.master_key is a string' do
      it 'creates a Lockbox instance successfully' do
        expect { subject.send(:lockbox) }.not_to raise_error
        expect(subject.send(:lockbox)).to be_a(Lockbox::Encryptor)
      end
    end

    context 'when Settings.lockbox.master_key is nil' do
      before do
        allow(Settings.lockbox).to receive(:master_key).and_return(nil)
      end

      it 'raises ArgumentError' do
        expect { subject.send(:lockbox) }
          .to raise_error(ArgumentError, 'Lockbox master key is required')
      end
    end

    context 'when Settings.lockbox.master_key is an unexpected type (env_parse_values edge case)' do
      before do
        # Simulate env_parse_values converting a numeric string to an integer
        allow(Settings.lockbox).to receive(:master_key).and_return(123)
      end

      it 'converts to string and attempts to use it' do
        # The integer will be converted to string, but Lockbox will reject it due to invalid format
        # This tests that our .to_s coercion happens before Lockbox validation
        expect { subject.send(:lockbox) }.to raise_error(Lockbox::Error)
      end
    end
  end
end
