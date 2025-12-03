# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vass::V0::Session, type: :model do
  let(:redis_client) { instance_double(Vass::RedisClient) }
  let(:valid_email) { 'veteran@example.com' }
  let(:valid_phone) { '5555551234' }
  let(:uuid) { SecureRandom.uuid }
  let(:otp_code) { '123456' }

  describe '.build' do
    it 'creates a new session instance' do
      session = described_class.build(contact_method: 'email', contact_value: valid_email)
      expect(session).to be_a(described_class)
    end
  end

  describe '#initialize' do
    context 'with direct parameters' do
      it 'sets attributes from direct parameters' do
        session = described_class.new(
          uuid:,
          contact_method: 'email',
          contact_value: valid_email,
          otp_code:
        )

        expect(session.uuid).to eq(uuid)
        expect(session.contact_method).to eq('email')
        expect(session.contact_value).to eq(valid_email)
        expect(session.otp_code).to eq(otp_code)
      end
    end

    context 'with data hash' do
      it 'sets attributes from data hash' do
        session = described_class.new(
          data: { contact_method: 'sms', contact_value: valid_phone }
        )

        expect(session.contact_method).to eq('sms')
        expect(session.contact_value).to eq(valid_phone)
      end
    end

    it 'generates a UUID if not provided' do
      session = described_class.new
      expect(session.uuid).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    end

    it 'creates a RedisClient if not provided' do
      session = described_class.new
      expect(session.redis_client).to be_a(Vass::RedisClient)
    end
  end

  describe '#valid_for_creation?' do
    context 'with valid email' do
      it 'returns true' do
        session = described_class.new(contact_method: 'email', contact_value: valid_email)
        expect(session.valid_for_creation?).to be true
      end
    end

    context 'with valid SMS' do
      it 'returns true for 10-digit phone' do
        session = described_class.new(contact_method: 'sms', contact_value: valid_phone)
        expect(session.valid_for_creation?).to be true
      end

      it 'returns true for phone with +1 prefix' do
        session = described_class.new(contact_method: 'sms', contact_value: "+1#{valid_phone}")
        expect(session.valid_for_creation?).to be true
      end

      it 'returns true for phone with formatting' do
        session = described_class.new(contact_method: 'sms', contact_value: '(555) 555-1234')
        expect(session.valid_for_creation?).to be true
      end
    end

    context 'with invalid contact method' do
      it 'returns false' do
        session = described_class.new(contact_method: 'invalid', contact_value: valid_email)
        expect(session.valid_for_creation?).to be false
      end
    end

    context 'with invalid email' do
      it 'returns false for malformed email' do
        session = described_class.new(contact_method: 'email', contact_value: 'not-an-email')
        expect(session.valid_for_creation?).to be false
      end
    end

    context 'with invalid phone' do
      it 'returns false for too short phone' do
        session = described_class.new(contact_method: 'sms', contact_value: '123')
        expect(session.valid_for_creation?).to be false
      end
    end

    context 'with blank contact value' do
      it 'returns false' do
        session = described_class.new(contact_method: 'email', contact_value: '')
        expect(session.valid_for_creation?).to be false
      end
    end
  end

  describe '#valid_for_validation?' do
    context 'with valid UUID and OTP' do
      it 'returns true' do
        session = described_class.new(uuid:, otp_code:)
        expect(session.valid_for_validation?).to be true
      end
    end

    context 'without UUID' do
      it 'returns false' do
        session = described_class.new(uuid: nil, otp_code:)
        expect(session.valid_for_validation?).to be false
      end
    end

    context 'without OTP code' do
      it 'returns false' do
        session = described_class.new(uuid:, otp_code: nil)
        expect(session.valid_for_validation?).to be false
      end
    end

    context 'with invalid OTP format' do
      it 'returns false for non-numeric code' do
        session = described_class.new(uuid:, otp_code: 'abcdef')
        expect(session.valid_for_validation?).to be false
      end

      it 'returns false for wrong length' do
        session = described_class.new(uuid:, otp_code: '123')
        expect(session.valid_for_validation?).to be false
      end
    end
  end

  describe '#generate_otp' do
    it 'generates a 6-digit numeric code' do
      session = described_class.new
      otp = session.generate_otp
      expect(otp).to match(/^\d{6}$/)
    end

    it 'pads with leading zeros' do
      session = described_class.new
      allow(SecureRandom).to receive(:random_number).and_return(123)
      otp = session.generate_otp
      expect(otp).to eq('000123')
    end
  end

  describe '#save_otp' do
    it 'saves the OTP to Redis' do
      session = described_class.new(uuid:, redis_client:)
      expect(redis_client).to receive(:save_otc).with(uuid:, code: otp_code)
      session.save_otp(otp_code)
    end
  end

  describe '#valid_otp?' do
    let(:session) { described_class.new(uuid:, otp_code:, redis_client:) }

    context 'when OTP matches' do
      it 'returns true' do
        allow(redis_client).to receive(:otc).with(uuid:).and_return(otp_code)
        expect(session.valid_otp?).to be true
      end
    end

    context 'when OTP does not match' do
      it 'returns false' do
        allow(redis_client).to receive(:otc).with(uuid:).and_return('999999')
        expect(session.valid_otp?).to be false
      end
    end

    context 'when OTP is not found in Redis' do
      it 'returns false' do
        allow(redis_client).to receive(:otc).with(uuid:).and_return(nil)
        expect(session.valid_otp?).to be false
      end
    end

    context 'when session is not valid for validation' do
      it 'returns false' do
        invalid_session = described_class.new(uuid: nil, otp_code: nil, redis_client:)
        expect(invalid_session.valid_otp?).to be false
      end
    end

    it 'uses constant-time comparison to prevent timing attacks' do
      allow(redis_client).to receive(:otc).with(uuid:).and_return(otp_code)
      expect(ActiveSupport::SecurityUtils).to receive(:secure_compare).with(otp_code, otp_code)
      session.valid_otp?
    end
  end

  describe '#delete_otp' do
    it 'deletes the OTP from Redis' do
      session = described_class.new(uuid:, redis_client:)
      expect(redis_client).to receive(:delete_otc).with(uuid:)
      session.delete_otp
    end
  end

  describe '#generate_session_token' do
    it 'generates a UUID session token' do
      session = described_class.new
      token = session.generate_session_token
      expect(token).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    end
  end

  describe '#creation_response' do
    it 'returns success response with UUID' do
      session = described_class.new(uuid:)
      response = session.creation_response
      expect(response).to eq({
                               uuid:,
                               message: 'OTP generated successfully'
                             })
    end
  end

  describe '#validation_response' do
    it 'returns success response with session token' do
      session = described_class.new
      token = SecureRandom.uuid
      response = session.validation_response(session_token: token)
      expect(response).to eq({
                               session_token: token,
                               message: 'OTP validated successfully'
                             })
    end
  end

  describe '#validation_error_response' do
    it 'returns error response' do
      session = described_class.new
      response = session.validation_error_response
      expect(response).to eq({
                               error: true,
                               message: 'Invalid session parameters'
                             })
    end
  end

  describe '#invalid_otp_response' do
    it 'returns error response' do
      session = described_class.new
      response = session.invalid_otp_response
      expect(response).to eq({
                               error: true,
                               message: 'Invalid OTP code'
                             })
    end
  end
end

