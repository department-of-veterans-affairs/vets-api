# frozen_string_literal: true

require 'rails_helper'

describe Vass::RedisClient do
  subject { described_class }

  let(:redis_client) { subject.build }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:redis_token_expiry) { 59.minutes }
  let(:redis_otp_expiry) { 10.minutes }
  let(:redis_session_expiry) { 2.hours }

  let(:uuid) { 'f5d4e6a1-b2c3-4d5e-6f7a-8b9c0d1e2f3a' }
  let(:oauth_token) { 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.test.token' }
  let(:otp_code) { '123456' }
  let(:last_name) { 'Smith' }
  let(:dob) { '1980-01-15' }
  let(:jti) { SecureRandom.uuid }
  let(:edipi) { '1234567890' }
  let(:veteran_id) { 'vet-uuid-123' }
  let(:token_encryptor) { instance_double(Vass::TokenEncryptor) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear

    # Mock the token encryptor to simplify testing
    # (Actual encryption behavior is tested in token_encryptor_spec.rb)
    allow(Vass::TokenEncryptor).to receive(:build).and_return(token_encryptor)
    allow(token_encryptor).to receive(:encrypt) { |token| "encrypted_#{token}" }
    allow(token_encryptor).to receive(:decrypt) { |token| token&.gsub(/^encrypted_/, '') }
  end

  describe 'attributes' do
    it 'responds to settings' do
      expect(redis_client.respond_to?(:settings)).to be(true)
    end

    it 'gets redis_token_expiry from settings' do
      expect(redis_client.settings.redis_token_expiry).to eq(redis_token_expiry)
    end

    it 'gets redis_otp_expiry from settings' do
      expect(redis_client.settings.redis_otp_expiry).to eq(redis_otp_expiry)
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

    context 'when cache exists with encrypted token' do
      before do
        redis_client.save_token(token: oauth_token)
      end

      it 'decrypts and returns the cached OAuth token' do
        expect(redis_client.token).to eq(oauth_token)
      end
    end

    context 'when cache has expired' do
      before do
        redis_client.save_token(token: oauth_token)
      end

      it 'returns nil' do
        Timecop.travel(redis_token_expiry.from_now) do
          expect(redis_client.token).to be_nil
        end
      end
    end
  end

  describe '#save_token' do
    it 'encrypts and saves the OAuth token in cache' do
      expect(redis_client.save_token(token: oauth_token)).to be(true)

      # Verify encrypted value is stored (not plaintext)
      encrypted_val = Rails.cache.read(
        'oauth_token',
        namespace: 'vass-auth-cache'
      )
      expect(encrypted_val).to eq("encrypted_#{oauth_token}")
      expect(encrypted_val).not_to eq(oauth_token)
    end

    it 'retrieves and decrypts the token correctly' do
      redis_client.save_token(token: oauth_token)

      # Use the public token method which should decrypt
      retrieved_token = redis_client.token
      expect(retrieved_token).to eq(oauth_token)
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

  describe 'OAuth token encryption integration' do
    it 'encrypts token on save and decrypts on retrieval' do
      expect(token_encryptor).to receive(:encrypt).with(oauth_token)
      expect(token_encryptor).to receive(:decrypt).with("encrypted_#{oauth_token}")

      redis_client.save_token(token: oauth_token)
      retrieved = redis_client.token

      expect(retrieved).to eq(oauth_token)
    end

    it 'handles nil tokens without calling encryptor' do
      expect(token_encryptor).not_to receive(:encrypt)

      redis_client.save_token(token: nil)
      expect(redis_client.token).to be_nil
    end

    context 'when encryption fails' do
      before do
        allow(token_encryptor).to receive(:encrypt)
          .and_raise(Vass::Errors::EncryptionError.new('Encryption failed'))
      end

      it 'raises EncryptionError' do
        expect do
          redis_client.save_token(token: oauth_token)
        end.to raise_error(Vass::Errors::EncryptionError)
      end
    end

    context 'when decryption fails' do
      before do
        # First save succeeds
        redis_client.save_token(token: oauth_token)

        # Then decryption fails on retrieval
        allow(token_encryptor).to receive(:decrypt)
          .and_raise(Vass::Errors::DecryptionError.new('Decryption failed'))
      end

      it 'raises DecryptionError' do
        expect do
          redis_client.token
        end.to raise_error(Vass::Errors::DecryptionError)
      end
    end

    context 'backward compatibility with plaintext tokens' do
      let(:plaintext_token) { 'old-plaintext-token' }

      before do
        # Simulate old plaintext token in cache
        Rails.cache.write(
          'oauth_token',
          plaintext_token,
          namespace: 'vass-auth-cache',
          expires_in: redis_token_expiry
        )

        # Encryptor returns plaintext as-is for backward compat
        allow(token_encryptor).to receive(:decrypt).with(plaintext_token).and_return(plaintext_token)
      end

      it 'retrieves plaintext token successfully' do
        retrieved = redis_client.token

        expect(retrieved).to eq(plaintext_token)
      end
    end
  end

  # ------------ OTP Management Tests ------------

  describe '#otp_data' do
    context 'when OTP cache exists' do
      before do
        redis_client.save_otp(uuid:, code: otp_code, last_name:, dob:)
      end

      it 'returns hash with code, last_name, and dob' do
        data = redis_client.otp_data(uuid:)
        expect(data[:code]).to eq(otp_code)
        expect(data[:last_name]).to eq(last_name)
        expect(data[:dob]).to eq(dob)
      end
    end

    context 'when OTP cache does not exist' do
      it 'returns nil' do
        expect(redis_client.otp_data(uuid:)).to be_nil
      end
    end

    context 'when OTP cache has expired' do
      before do
        redis_client.save_otp(uuid:, code: otp_code, last_name:, dob:)
      end

      it 'returns nil' do
        Timecop.travel(redis_otp_expiry.from_now) do
          expect(redis_client.otp_data(uuid:)).to be_nil
        end
      end
    end
  end

  describe '#save_otp' do
    it 'saves the OTP in cache with uuid key' do
      expect(redis_client.save_otp(uuid:, code: otp_code, last_name:, dob:)).to be(true)

      data = redis_client.otp_data(uuid:)
      expect(data[:code]).to eq(otp_code)
      expect(data[:last_name]).to eq(last_name)
      expect(data[:dob]).to eq(dob)
    end

    it 'uses shorter expiry than OAuth token' do
      redis_client.save_otp(uuid:, code: otp_code, last_name:, dob:)

      # Should still be present before OTP expiry
      Timecop.travel((redis_otp_expiry - 1.minute).from_now) do
        expect(redis_client.otp_data(uuid:)&.dig(:code)).to eq(otp_code)
      end

      # Should be gone after OTP expiry (but before token expiry)
      Timecop.travel(redis_otp_expiry.from_now) do
        expect(redis_client.otp_data(uuid:)).to be_nil
      end
    end
  end

  describe '#delete_otp' do
    before do
      redis_client.save_otp(uuid:, code: otp_code, last_name:, dob:)
    end

    it 'removes the OTP from cache' do
      expect(redis_client.otp_data(uuid:)&.dig(:code)).to eq(otp_code)

      redis_client.delete_otp(uuid:)

      expect(redis_client.otp_data(uuid:)).to be_nil
    end

    it 'does not error when deleting non-existent OTP' do
      redis_client.delete_otp(uuid:)
      expect { redis_client.delete_otp(uuid:) }.not_to raise_error
    end
  end

  describe 'OTP isolation by UUID' do
    let(:uuid1) { 'uuid-1111-aaaa' }
    let(:uuid2) { 'uuid-2222-bbbb' }
    let(:code1) { '111111' }
    let(:code2) { '222222' }

    it 'stores OTPs separately for different UUIDs' do
      redis_client.save_otp(uuid: uuid1, code: code1, last_name:, dob:)
      redis_client.save_otp(uuid: uuid2, code: code2, last_name:, dob:)

      expect(redis_client.otp_data(uuid: uuid1)&.dig(:code)).to eq(code1)
      expect(redis_client.otp_data(uuid: uuid2)&.dig(:code)).to eq(code2)
    end

    it 'deletes OTP for one UUID without affecting others' do
      redis_client.save_otp(uuid: uuid1, code: code1, last_name:, dob:)
      redis_client.save_otp(uuid: uuid2, code: code2, last_name:, dob:)

      redis_client.delete_otp(uuid: uuid1)

      expect(redis_client.otp_data(uuid: uuid1)).to be_nil
      expect(redis_client.otp_data(uuid: uuid2)&.dig(:code)).to eq(code2)
    end
  end

  # ------------ Session Management Tests ------------

  describe '#save_session' do
    it 'saves session data in cache' do
      expect(
        redis_client.save_session(
          uuid:,
          jti:,
          edipi:,
          veteran_id:
        )
      ).to be(true)

      val = Rails.cache.read(
        "session_#{uuid}",
        namespace: 'vass-session-cache'
      )
      expect(val).to be_present
    end

    it 'stores jti, EDIPI, and veteran_id' do
      redis_client.save_session(
        uuid:,
        jti:,
        edipi:,
        veteran_id:
      )

      session_data = redis_client.session(uuid:)
      expect(session_data[:jti]).to eq(jti)
      expect(session_data[:edipi]).to eq(edipi)
      expect(session_data[:veteran_id]).to eq(veteran_id)
    end
  end

  describe '#session' do
    context 'when session does not exist' do
      it 'returns nil' do
        expect(redis_client.session(uuid:)).to be_nil
      end
    end

    context 'when session exists' do
      before do
        redis_client.save_session(
          uuid:,
          jti:,
          edipi:,
          veteran_id:
        )
      end

      it 'returns session data as hash' do
        session_data = redis_client.session(uuid:)
        expect(session_data).to be_a(Hash)
        expect(session_data[:jti]).to eq(jti)
        expect(session_data[:edipi]).to eq(edipi)
        expect(session_data[:veteran_id]).to eq(veteran_id)
      end
    end

    context 'when session has expired' do
      before do
        redis_client.save_session(
          uuid:,
          jti:,
          edipi:,
          veteran_id:
        )
      end

      it 'returns nil' do
        Timecop.travel(redis_session_expiry.from_now) do
          expect(redis_client.session(uuid:)).to be_nil
        end
      end
    end

    context 'when session data is corrupted' do
      before do
        # Write invalid JSON to cache
        Rails.cache.write(
          "session_#{uuid}",
          'invalid json {corrupt data',
          namespace: 'vass-session-cache'
        )
      end

      it 'returns nil' do
        expect(redis_client.session(uuid:)).to be_nil
      end

      it 'logs the parse error without PHI' do
        allow(Rails.logger).to receive(:error).and_call_original
        expect(Rails.logger).to receive(:error)
          .with(a_string_including('"service":"vass"', '"component":"redis_client"',
                                   '"action":"json_parse_failed"', '"key_type":"session_data"'))
          .and_call_original
        redis_client.session(uuid:)
      end
    end
  end

  describe '#edipi' do
    context 'when session does not exist' do
      it 'returns nil' do
        expect(redis_client.edipi(uuid:)).to be_nil
      end
    end

    context 'when session exists' do
      before do
        redis_client.save_session(
          uuid:,
          jti:,
          edipi:,
          veteran_id:
        )
      end

      it 'returns EDIPI from session' do
        expect(redis_client.edipi(uuid:)).to eq(edipi)
      end
    end
  end

  describe '#veteran_id' do
    context 'when session does not exist' do
      it 'returns nil' do
        expect(redis_client.veteran_id(uuid:)).to be_nil
      end
    end

    context 'when session exists' do
      before do
        redis_client.save_session(
          uuid:,
          jti:,
          edipi:,
          veteran_id:
        )
      end

      it 'returns veteran_id from session' do
        expect(redis_client.veteran_id(uuid:)).to eq(veteran_id)
      end
    end
  end

  describe '#session_exists?' do
    context 'when session does not exist' do
      it 'returns false' do
        expect(redis_client.session_exists?(uuid:)).to be(false)
      end
    end

    context 'when session exists' do
      before do
        redis_client.save_session(
          uuid:,
          jti:,
          edipi:,
          veteran_id:
        )
      end

      it 'returns true' do
        expect(redis_client.session_exists?(uuid:)).to be(true)
      end
    end

    context 'when session has been deleted (revoked)' do
      before do
        redis_client.save_session(
          uuid:,
          jti:,
          edipi:,
          veteran_id:
        )
        redis_client.delete_session(uuid:)
      end

      it 'returns false' do
        expect(redis_client.session_exists?(uuid:)).to be(false)
      end
    end
  end

  describe '#session_valid_for_jti?' do
    context 'when session does not exist' do
      it 'returns false' do
        expect(redis_client.session_valid_for_jti?(uuid:, jti:)).to be(false)
      end
    end

    context 'when session exists with matching jti' do
      before do
        redis_client.save_session(uuid:, jti:, edipi:, veteran_id:)
      end

      it 'returns true' do
        expect(redis_client.session_valid_for_jti?(uuid:, jti:)).to be(true)
      end
    end

    context 'when session exists with different jti' do
      let(:old_jti) { SecureRandom.uuid }
      let(:new_jti) { SecureRandom.uuid }

      before do
        redis_client.save_session(uuid:, jti: new_jti, edipi:, veteran_id:)
      end

      it 'returns false for old jti' do
        expect(redis_client.session_valid_for_jti?(uuid:, jti: old_jti)).to be(false)
      end

      it 'returns true for new jti' do
        expect(redis_client.session_valid_for_jti?(uuid:, jti: new_jti)).to be(true)
      end
    end

    context 'when new token is issued (re-authentication)' do
      let(:first_jti) { SecureRandom.uuid }
      let(:second_jti) { SecureRandom.uuid }

      it 'invalidates the previous token' do
        # First authentication
        redis_client.save_session(uuid:, jti: first_jti, edipi:, veteran_id:)
        expect(redis_client.session_valid_for_jti?(uuid:, jti: first_jti)).to be(true)

        # Second authentication overwrites session with new jti
        redis_client.save_session(uuid:, jti: second_jti, edipi:, veteran_id:)

        # First token is now invalid
        expect(redis_client.session_valid_for_jti?(uuid:, jti: first_jti)).to be(false)
        # Second token is valid
        expect(redis_client.session_valid_for_jti?(uuid:, jti: second_jti)).to be(true)
      end
    end
  end

  describe '#delete_session' do
    before do
      redis_client.save_session(
        uuid:,
        jti:,
        edipi:,
        veteran_id:
      )
    end

    it 'removes session data from cache' do
      expect(redis_client.session(uuid:)).to be_present

      redis_client.delete_session(uuid:)

      expect(redis_client.session(uuid:)).to be_nil
    end

    it 'does not error when deleting non-existent session' do
      redis_client.delete_session(uuid:)
      expect { redis_client.delete_session(uuid:) }.not_to raise_error
    end
  end

  describe 'session isolation by uuid' do
    let(:uuid1) { SecureRandom.uuid }
    let(:uuid2) { SecureRandom.uuid }
    let(:jti1) { SecureRandom.uuid }
    let(:jti2) { SecureRandom.uuid }
    let(:edipi1) { '1111111111' }
    let(:edipi2) { '2222222222' }

    it 'stores sessions separately for different uuids' do
      redis_client.save_session(uuid: uuid1, jti: jti1, edipi: edipi1, veteran_id: 'vet-1')
      redis_client.save_session(uuid: uuid2, jti: jti2, edipi: edipi2, veteran_id: 'vet-2')

      expect(redis_client.edipi(uuid: uuid1)).to eq(edipi1)
      expect(redis_client.edipi(uuid: uuid2)).to eq(edipi2)
    end

    it 'deletes session for one uuid without affecting others' do
      redis_client.save_session(uuid: uuid1, jti: jti1, edipi: edipi1, veteran_id: 'vet-1')
      redis_client.save_session(uuid: uuid2, jti: jti2, edipi: edipi2, veteran_id: 'vet-2')

      redis_client.delete_session(uuid: uuid1)

      expect(redis_client.session(uuid: uuid1)).to be_nil
      expect(redis_client.edipi(uuid: uuid2)).to eq(edipi2)
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
