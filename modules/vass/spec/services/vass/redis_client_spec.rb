# frozen_string_literal: true

require 'rails_helper'

describe Vass::RedisClient do
  subject { described_class }

  let(:redis_client) { subject.build }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:redis_token_expiry) { 59.minutes }
  let(:redis_otc_expiry) { 10.minutes }
  let(:redis_session_expiry) { 2.hours }

  let(:uuid) { 'f5d4e6a1-b2c3-4d5e-6f7a-8b9c0d1e2f3a' }
  let(:oauth_token) { 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.test.token' }
  let(:otc_code) { '123456' }
  let(:session_token) { SecureRandom.uuid }
  let(:edipi) { '1234567890' }
  let(:veteran_id) { 'vet-uuid-123' }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe 'attributes' do
    it 'responds to settings' do
      expect(redis_client.respond_to?(:settings)).to be(true)
    end

    it 'gets redis_token_expiry from settings' do
      expect(redis_client.settings.redis_token_expiry).to eq(redis_token_expiry)
    end

    it 'gets redis_otc_expiry from settings' do
      expect(redis_client.settings.redis_otc_expiry).to eq(redis_otc_expiry)
    end

    it 'gets redis_session_expiry from settings' do
      expect(redis_client.settings.redis_session_expiry).to eq(redis_session_expiry)
    end
  end

  describe '.build' do
    it 'returns an instance of RedisClient' do
      expect(redis_client).to be_an_instance_of(Vass::RedisClient)
    end
  end

  # ------------ OAuth Token Management Tests ------------

  describe '#token' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.token).to be_nil
      end
    end

    context 'when cache exists' do
      before do
        Rails.cache.write(
          'oauth_token',
          oauth_token,
          namespace: 'vass-auth-cache',
          expires_in: redis_token_expiry
        )
      end

      it 'returns the cached OAuth token' do
        expect(redis_client.token).to eq(oauth_token)
      end
    end

    context 'when cache has expired' do
      before do
        Rails.cache.write(
          'oauth_token',
          oauth_token,
          namespace: 'vass-auth-cache',
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
    it 'saves the OAuth token in cache' do
      expect(redis_client.save_token(token: oauth_token)).to be(true)

      val = Rails.cache.read(
        'oauth_token',
        namespace: 'vass-auth-cache'
      )
      expect(val).to eq(oauth_token)
    end

    it 'clears the token when passed nil' do
      redis_client.save_token(token: oauth_token)
      redis_client.save_token(token: nil)

      val = Rails.cache.read(
        'oauth_token',
        namespace: 'vass-auth-cache'
      )
      expect(val).to be_nil
    end
  end

  # ------------ OTC Management Tests ------------

  describe '#otc' do
    context 'when OTC cache does not exist' do
      it 'returns nil' do
        expect(redis_client.otc(uuid:)).to be_nil
      end
    end

    context 'when OTC cache exists' do
      before do
        Rails.cache.write(
          "otc_#{uuid}",
          otc_code,
          namespace: 'vass-otc-cache',
          expires_in: redis_otc_expiry
        )
      end

      it 'returns the cached OTC' do
        expect(redis_client.otc(uuid:)).to eq(otc_code)
      end
    end

    context 'when OTC cache has expired' do
      before do
        Rails.cache.write(
          "otc_#{uuid}",
          otc_code,
          namespace: 'vass-otc-cache',
          expires_in: redis_otc_expiry
        )
      end

      it 'returns nil' do
        Timecop.travel(redis_otc_expiry.from_now) do
          expect(redis_client.otc(uuid:)).to be_nil
        end
      end
    end
  end

  describe '#save_otc' do
    it 'saves the OTC in cache with uuid key' do
      expect(redis_client.save_otc(uuid:, code: otc_code)).to be(true)

      val = Rails.cache.read(
        "otc_#{uuid}",
        namespace: 'vass-otc-cache'
      )
      expect(val).to eq(otc_code)
    end

    it 'uses shorter expiry than OAuth token' do
      redis_client.save_otc(uuid:, code: otc_code)

      # Should still be present before OTC expiry
      Timecop.travel((redis_otc_expiry - 1.minute).from_now) do
        expect(redis_client.otc(uuid:)).to eq(otc_code)
      end

      # Should be gone after OTC expiry (but before token expiry)
      Timecop.travel(redis_otc_expiry.from_now) do
        expect(redis_client.otc(uuid:)).to be_nil
      end
    end
  end

  describe '#delete_otc' do
    before do
      redis_client.save_otc(uuid:, code: otc_code)
    end

    it 'removes the OTC from cache' do
      expect(redis_client.otc(uuid:)).to eq(otc_code)

      redis_client.delete_otc(uuid:)

      expect(redis_client.otc(uuid:)).to be_nil
    end

    it 'does not error when deleting non-existent OTC' do
      redis_client.delete_otc(uuid:)
      expect { redis_client.delete_otc(uuid:) }.not_to raise_error
    end
  end

  describe 'OTC isolation by UUID' do
    let(:uuid1) { 'uuid-1111-aaaa' }
    let(:uuid2) { 'uuid-2222-bbbb' }
    let(:code1) { '111111' }
    let(:code2) { '222222' }

    it 'stores OTCs separately for different UUIDs' do
      redis_client.save_otc(uuid: uuid1, code: code1)
      redis_client.save_otc(uuid: uuid2, code: code2)

      expect(redis_client.otc(uuid: uuid1)).to eq(code1)
      expect(redis_client.otc(uuid: uuid2)).to eq(code2)
    end

    it 'deletes OTC for one UUID without affecting others' do
      redis_client.save_otc(uuid: uuid1, code: code1)
      redis_client.save_otc(uuid: uuid2, code: code2)

      redis_client.delete_otc(uuid: uuid1)

      expect(redis_client.otc(uuid: uuid1)).to be_nil
      expect(redis_client.otc(uuid: uuid2)).to eq(code2)
    end
  end

  # ------------ Session Management Tests ------------

  describe '#save_session' do
    it 'saves session data in cache' do
      expect(
        redis_client.save_session(
          session_token:,
          edipi:,
          veteran_id:,
          uuid:
        )
      ).to be(true)

      val = Rails.cache.read(
        "session_#{session_token}",
        namespace: 'vass-session-cache'
      )
      expect(val).to be_present
    end

    it 'stores EDIPI, veteran_id, and uuid' do
      redis_client.save_session(
        session_token:,
        edipi:,
        veteran_id:,
        uuid:
      )

      session_data = redis_client.session(session_token:)
      expect(session_data[:edipi]).to eq(edipi)
      expect(session_data[:veteran_id]).to eq(veteran_id)
      expect(session_data[:uuid]).to eq(uuid)
    end
  end

  describe '#session' do
    context 'when session does not exist' do
      it 'returns nil' do
        expect(redis_client.session(session_token:)).to be_nil
      end
    end

    context 'when session exists' do
      before do
        redis_client.save_session(
          session_token:,
          edipi:,
          veteran_id:,
          uuid:
        )
      end

      it 'returns session data as hash' do
        session_data = redis_client.session(session_token:)
        expect(session_data).to be_a(Hash)
        expect(session_data[:edipi]).to eq(edipi)
        expect(session_data[:veteran_id]).to eq(veteran_id)
      end
    end

    context 'when session has expired' do
      before do
        redis_client.save_session(
          session_token:,
          edipi:,
          veteran_id:,
          uuid:
        )
      end

      it 'returns nil' do
        Timecop.travel(redis_session_expiry.from_now) do
          expect(redis_client.session(session_token:)).to be_nil
        end
      end
    end

    context 'when session data is corrupted' do
      before do
        # Write invalid JSON to cache
        Rails.cache.write(
          "session_#{session_token}",
          'invalid json {corrupt data',
          namespace: 'vass-session-cache'
        )
      end

      it 'returns nil' do
        expect(redis_client.session(session_token:)).to be_nil
      end

      it 'logs the parse error without PHI' do
        expect(Rails.logger).to receive(:error).with(hash_including(
                                                       service: 'vass',
                                                       component: 'redis_client',
                                                       action: 'json_parse_failed',
                                                       key_type: 'session_data'
                                                     ))
        redis_client.session(session_token:)
      end
    end
  end

  describe '#edipi' do
    context 'when session does not exist' do
      it 'returns nil' do
        expect(redis_client.edipi(session_token:)).to be_nil
      end
    end

    context 'when session exists' do
      before do
        redis_client.save_session(
          session_token:,
          edipi:,
          veteran_id:,
          uuid:
        )
      end

      it 'returns EDIPI from session' do
        expect(redis_client.edipi(session_token:)).to eq(edipi)
      end
    end
  end

  describe '#veteran_id' do
    context 'when session does not exist' do
      it 'returns nil' do
        expect(redis_client.veteran_id(session_token:)).to be_nil
      end
    end

    context 'when session exists' do
      before do
        redis_client.save_session(
          session_token:,
          edipi:,
          veteran_id:,
          uuid:
        )
      end

      it 'returns veteran_id from session' do
        expect(redis_client.veteran_id(session_token:)).to eq(veteran_id)
      end
    end
  end

  describe '#delete_session' do
    before do
      redis_client.save_session(
        session_token:,
        edipi:,
        veteran_id:,
        uuid:
      )
    end

    it 'removes session data from cache' do
      expect(redis_client.session(session_token:)).to be_present

      redis_client.delete_session(session_token:)

      expect(redis_client.session(session_token:)).to be_nil
    end

    it 'does not error when deleting non-existent session' do
      redis_client.delete_session(session_token:)
      expect { redis_client.delete_session(session_token:) }.not_to raise_error
    end
  end

  describe 'session isolation by token' do
    let(:token1) { SecureRandom.uuid }
    let(:token2) { SecureRandom.uuid }
    let(:edipi1) { '1111111111' }
    let(:edipi2) { '2222222222' }

    it 'stores sessions separately for different tokens' do
      redis_client.save_session(session_token: token1, edipi: edipi1, veteran_id: 'vet-1', uuid:)
      redis_client.save_session(session_token: token2, edipi: edipi2, veteran_id: 'vet-2', uuid:)

      expect(redis_client.edipi(session_token: token1)).to eq(edipi1)
      expect(redis_client.edipi(session_token: token2)).to eq(edipi2)
    end

    it 'deletes session for one token without affecting others' do
      redis_client.save_session(session_token: token1, edipi: edipi1, veteran_id: 'vet-1', uuid:)
      redis_client.save_session(session_token: token2, edipi: edipi2, veteran_id: 'vet-2', uuid:)

      redis_client.delete_session(session_token: token1)

      expect(redis_client.session(session_token: token1)).to be_nil
      expect(redis_client.edipi(session_token: token2)).to eq(edipi2)
    end
  end

  # ------------ Rate Limiting Tests ------------

  describe '#rate_limit_count' do
    let(:identifier) { 'test@example.com' }

    context 'when no rate limit has been set' do
      it 'returns 0' do
        expect(redis_client.rate_limit_count(identifier:)).to eq(0)
      end
    end

    context 'when rate limit counter exists' do
      before do
        redis_client.increment_rate_limit(identifier:)
        redis_client.increment_rate_limit(identifier:)
      end

      it 'returns the current count' do
        expect(redis_client.rate_limit_count(identifier:)).to eq(2)
      end
    end
  end

  describe '#increment_rate_limit' do
    let(:identifier) { 'test@example.com' }

    it 'increments the counter from 0 to 1' do
      count = redis_client.increment_rate_limit(identifier:)
      expect(count).to eq(1)
    end

    it 'increments the counter multiple times' do
      redis_client.increment_rate_limit(identifier:)
      redis_client.increment_rate_limit(identifier:)
      count = redis_client.increment_rate_limit(identifier:)
      expect(count).to eq(3)
    end

    it 'sets expiration on the counter' do
      redis_client.increment_rate_limit(identifier:)

      # Before expiry, count should be present
      expect(redis_client.rate_limit_count(identifier:)).to eq(1)

      # After expiry, count should reset to 0
      Timecop.travel(redis_client.send(:rate_limit_expiry).seconds.from_now) do
        expect(redis_client.rate_limit_count(identifier:)).to eq(0)
      end
    end
  end

  describe '#rate_limit_exceeded?' do
    let(:identifier) { 'test@example.com' }

    context 'when count is below limit' do
      before do
        3.times { redis_client.increment_rate_limit(identifier:) }
      end

      it 'returns false' do
        expect(redis_client.rate_limit_exceeded?(identifier:)).to be false
      end
    end

    context 'when count equals limit' do
      before do
        # Use the settings value
        redis_client.send(:rate_limit_max_attempts).times do
          redis_client.increment_rate_limit(identifier:)
        end
      end

      it 'returns true' do
        expect(redis_client.rate_limit_exceeded?(identifier:)).to be true
      end
    end

    context 'when count exceeds limit' do
      before do
        # Use the settings value + 2
        (redis_client.send(:rate_limit_max_attempts) + 2).times do
          redis_client.increment_rate_limit(identifier:)
        end
      end

      it 'returns true' do
        expect(redis_client.rate_limit_exceeded?(identifier:)).to be true
      end
    end
  end

  describe '#reset_rate_limit' do
    let(:identifier) { 'test@example.com' }

    before do
      3.times { redis_client.increment_rate_limit(identifier:) }
    end

    it 'resets the counter to 0' do
      expect(redis_client.rate_limit_count(identifier:)).to eq(3)

      redis_client.reset_rate_limit(identifier:)

      expect(redis_client.rate_limit_count(identifier:)).to eq(0)
    end

    it 'does not error when resetting non-existent counter' do
      expect { redis_client.reset_rate_limit(identifier: 'nonexistent@example.com') }.not_to raise_error
    end
  end

  describe 'rate limit isolation by identifier' do
    let(:identifier1) { 'user1@example.com' }
    let(:identifier2) { 'user2@example.com' }

    it 'tracks rate limits separately for different identifiers' do
      2.times { redis_client.increment_rate_limit(identifier: identifier1) }
      3.times { redis_client.increment_rate_limit(identifier: identifier2) }

      expect(redis_client.rate_limit_count(identifier: identifier1)).to eq(2)
      expect(redis_client.rate_limit_count(identifier: identifier2)).to eq(3)
    end

    it 'resets rate limit for one identifier without affecting others' do
      2.times { redis_client.increment_rate_limit(identifier: identifier1) }
      3.times { redis_client.increment_rate_limit(identifier: identifier2) }

      redis_client.reset_rate_limit(identifier: identifier1)

      expect(redis_client.rate_limit_count(identifier: identifier1)).to eq(0)
      expect(redis_client.rate_limit_count(identifier: identifier2)).to eq(3)
    end
  end

  describe 'rate limit key generation' do
    it 'uses identifier directly in cache key' do
      identifier = 'da1e1a40-1e63-f011-bec2-001dd80351ea'
      redis_client.increment_rate_limit(identifier:)

      expect(
        Rails.cache.exist?(
          "rate_limit_#{identifier}",
          namespace: 'vass-rate-limit-cache'
        )
      ).to be true
    end

    it 'normalizes identifiers to be case-insensitive' do
      redis_client.increment_rate_limit(identifier: 'TEST-UUID-123')
      redis_client.increment_rate_limit(identifier: 'test-uuid-123')

      expect(redis_client.rate_limit_count(identifier: 'test-uuid-123')).to eq(2)
      expect(redis_client.rate_limit_count(identifier: 'TEST-UUID-123')).to eq(2)
    end

    it 'strips whitespace from identifiers' do
      redis_client.increment_rate_limit(identifier: '  test-uuid-123  ')
      redis_client.increment_rate_limit(identifier: 'test-uuid-123')

      expect(redis_client.rate_limit_count(identifier: '  test-uuid-123  ')).to eq(2)
      expect(redis_client.rate_limit_count(identifier: 'test-uuid-123')).to eq(2)
    end
  end

  # ------------ Booking Session Tests ------------

  describe '#store_booking_session' do
    let(:veteran_id) { 'vet-booking-123' }
    let(:booking_data) do
      {
        appointment_id: 'cohort-abc',
        time_start_utc: '2026-01-10T10:00:00Z',
        time_end_utc: '2026-01-10T10:30:00Z'
      }
    end

    it 'stores booking session data in cache' do
      result = redis_client.store_booking_session(veteran_id:, data: booking_data)

      expect(result).to be true

      cached_data = redis_client.get_booking_session(veteran_id:)
      expect(cached_data[:appointment_id]).to eq('cohort-abc')
      expect(cached_data[:time_start_utc]).to eq('2026-01-10T10:00:00Z')
      expect(cached_data[:time_end_utc]).to eq('2026-01-10T10:30:00Z')
    end

    it 'uses 1 hour expiration' do
      redis_client.store_booking_session(veteran_id:, data: booking_data)

      expect(redis_client.get_booking_session(veteran_id:)).not_to be_empty

      Timecop.travel(3601.seconds.from_now) do
        expect(redis_client.get_booking_session(veteran_id:)).to be_empty
      end
    end

    it 'overwrites existing booking session' do
      redis_client.store_booking_session(
        veteran_id:,
        data: { appointment_id: 'old-id' }
      )
      redis_client.store_booking_session(
        veteran_id:,
        data: { appointment_id: 'new-id' }
      )

      cached_data = redis_client.get_booking_session(veteran_id:)
      expect(cached_data[:appointment_id]).to eq('new-id')
    end
  end

  describe '#get_booking_session' do
    let(:veteran_id) { 'vet-get-session' }

    context 'when session does not exist' do
      it 'returns empty hash' do
        expect(redis_client.get_booking_session(veteran_id:)).to eq({})
      end
    end

    context 'when session exists' do
      before do
        redis_client.store_booking_session(
          veteran_id:,
          data: { appointment_id: 'cohort-xyz', time_start_utc: '2026-01-15T14:00:00Z' }
        )
      end

      it 'returns session data' do
        result = redis_client.get_booking_session(veteran_id:)

        expect(result).to be_a(Hash)
        expect(result[:appointment_id]).to eq('cohort-xyz')
        expect(result[:time_start_utc]).to eq('2026-01-15T14:00:00Z')
      end
    end

    context 'when session has expired' do
      before do
        redis_client.store_booking_session(
          veteran_id:,
          data: { appointment_id: 'expired' }
        )

        Timecop.travel(3601.seconds.from_now) do
          @result = redis_client.get_booking_session(veteran_id:)
        end
      end

      it 'returns empty hash' do
        expect(@result).to eq({})
      end
    end
  end

  describe '#update_booking_session' do
    let(:veteran_id) { 'vet-update-session' }

    context 'when session does not exist' do
      it 'creates new session with provided data' do
        redis_client.update_booking_session(
          veteran_id:,
          data: { appointment_id: 'new-cohort' }
        )

        result = redis_client.get_booking_session(veteran_id:)
        expect(result[:appointment_id]).to eq('new-cohort')
      end
    end

    context 'when session exists' do
      before do
        redis_client.store_booking_session(
          veteran_id:,
          data: { appointment_id: 'cohort-123', step: 1 }
        )
      end

      it 'merges new data with existing data' do
        redis_client.update_booking_session(
          veteran_id:,
          data: { time_start_utc: '2026-01-20T09:00:00Z', step: 2 }
        )

        result = redis_client.get_booking_session(veteran_id:)
        expect(result[:appointment_id]).to eq('cohort-123')
        expect(result[:time_start_utc]).to eq('2026-01-20T09:00:00Z')
        expect(result[:step]).to eq(2)
      end

      it 'overwrites existing keys' do
        redis_client.update_booking_session(
          veteran_id:,
          data: { appointment_id: 'updated-cohort' }
        )

        result = redis_client.get_booking_session(veteran_id:)
        expect(result[:appointment_id]).to eq('updated-cohort')
        expect(result[:step]).to eq(1)
      end
    end
  end

  describe '#delete_booking_session' do
    let(:veteran_id) { 'vet-delete-session' }

    before do
      redis_client.store_booking_session(
        veteran_id:,
        data: { appointment_id: 'to-be-deleted' }
      )
    end

    it 'removes booking session from cache' do
      expect(redis_client.get_booking_session(veteran_id:)).not_to be_empty

      redis_client.delete_booking_session(veteran_id:)

      expect(redis_client.get_booking_session(veteran_id:)).to be_empty
    end

    it 'does not error when deleting non-existent session' do
      expect do
        redis_client.delete_booking_session(veteran_id: 'nonexistent-vet')
      end.not_to raise_error
    end
  end

  describe 'booking session isolation' do
    let(:veteran_id1) { 'vet-1' }
    let(:veteran_id2) { 'vet-2' }

    it 'stores sessions separately for different veterans' do
      redis_client.store_booking_session(
        veteran_id: veteran_id1,
        data: { appointment_id: 'cohort-1' }
      )
      redis_client.store_booking_session(
        veteran_id: veteran_id2,
        data: { appointment_id: 'cohort-2' }
      )

      session1 = redis_client.get_booking_session(veteran_id: veteran_id1)
      session2 = redis_client.get_booking_session(veteran_id: veteran_id2)

      expect(session1[:appointment_id]).to eq('cohort-1')
      expect(session2[:appointment_id]).to eq('cohort-2')
    end

    it 'deletes session for one veteran without affecting others' do
      redis_client.store_booking_session(
        veteran_id: veteran_id1,
        data: { appointment_id: 'cohort-1' }
      )
      redis_client.store_booking_session(
        veteran_id: veteran_id2,
        data: { appointment_id: 'cohort-2' }
      )

      redis_client.delete_booking_session(veteran_id: veteran_id1)

      expect(redis_client.get_booking_session(veteran_id: veteran_id1)).to be_empty
      expect(redis_client.get_booking_session(veteran_id: veteran_id2)).not_to be_empty
    end
  end
end
