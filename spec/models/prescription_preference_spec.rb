# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrescriptionPreference, type: :model do
  subject(:preference) { described_class.new(email_address: 'test@example.com', rx_flag: true) }

  describe 'attributes' do
    it 'has email_address attribute' do
      expect(preference).to respond_to(:email_address)
      expect(preference.email_address).to eq('test@example.com')
    end

    it 'has rx_flag attribute' do
      expect(preference).to respond_to(:rx_flag)
      expect(preference.rx_flag).to be true
    end
  end

  describe 'validations' do
    describe 'email_address validation' do
      it 'is valid with a proper email address' do
        preference.email_address = 'valid@example.com'
        expect(preference).to be_valid
      end

      it 'is invalid without an email address' do
        preference.email_address = nil
        expect(preference).not_to be_valid
        expect(preference.errors[:email_address]).to include("can't be blank")
      end

      it 'is invalid with an empty email address' do
        preference.email_address = ''
        expect(preference).not_to be_valid
        expect(preference.errors[:email_address]).to include("can't be blank")
      end

      it 'is invalid with an improperly formatted email' do
        preference.email_address = 'invalid-email'
        expect(preference).not_to be_valid
        expect(preference.errors[:email_address]).to include('is invalid')
      end

      it 'is invalid with email missing @ symbol' do
        preference.email_address = 'testexample.com'
        expect(preference).not_to be_valid
        expect(preference.errors[:email_address]).to include('is invalid')
      end

      it 'is invalid with email missing domain' do
        preference.email_address = 'test@'
        expect(preference).not_to be_valid
        expect(preference.errors[:email_address]).to include('is invalid')
      end

      it 'is invalid with email too short (less than 6 characters)' do
        preference.email_address = 'a@b.c'
        expect(preference).not_to be_valid
        expect(preference.errors[:email_address]).to include('is too short (minimum is 6 characters)')
      end

      it 'is valid with email exactly 6 characters' do
        preference.email_address = 'a@b.co'
        expect(preference).to be_valid
      end

      it 'is invalid with email too long (more than 255 characters)' do
        long_email = "#{'a' * 240}@example.com" # 253 characters total
        preference.email_address = long_email
        expect(preference).to be_valid

        very_long_email = "#{'a' * 250}@example.com" # 263 characters total
        preference.email_address = very_long_email
        expect(preference).not_to be_valid
        expect(preference.errors[:email_address]).to include('is too long (maximum is 255 characters)')
      end

      it 'accepts various valid email formats' do
        valid_emails = [
          'test@example.com',
          'user.name@example.com',
          'user+tag@example.com',
          'user123@example-site.com',
          'firstname.lastname@domain.co.uk'
        ]

        valid_emails.each do |email|
          preference.email_address = email
          expect(preference).to be_valid, "Expected #{email} to be valid"
        end
      end
    end

    describe 'rx_flag validation' do
      it 'is valid when rx_flag is true' do
        preference.rx_flag = true
        expect(preference).to be_valid
      end

      it 'is valid when rx_flag is false' do
        preference.rx_flag = false
        expect(preference).to be_valid
      end

      it 'is invalid when rx_flag is nil' do
        preference.rx_flag = nil
        expect(preference).not_to be_valid
        expect(preference.errors[:rx_flag]).to include('is not included in the list')
      end

      it 'handles string values that coerce to boolean' do
        # NOTE: The Bool type in this system may coerce strings to boolean
        # This test documents the actual behavior
        preference.rx_flag = 'true'
        expect(preference.rx_flag).to be_truthy

        preference.rx_flag = 'false'
        expect(preference.rx_flag).to be_falsey
      end
    end

    describe 'combined validations' do
      it 'is valid with both valid email and boolean rx_flag' do
        preference.email_address = 'valid@example.com'
        preference.rx_flag = false
        expect(preference).to be_valid
      end

      it 'is invalid when both email and rx_flag are invalid' do
        preference.email_address = 'invalid-email'
        preference.rx_flag = nil
        expect(preference).not_to be_valid
        expect(preference.errors[:email_address]).to be_present
        expect(preference.errors[:rx_flag]).to be_present
      end
    end
  end

  describe '#mhv_params' do
    context 'when valid' do
      it 'returns a hash with email_address and rx_flag' do
        expected_params = {
          email_address: 'test@example.com',
          rx_flag: true
        }
        expect(preference.mhv_params).to eq(expected_params)
      end

      it 'returns correct params when rx_flag is false' do
        preference.rx_flag = false
        expected_params = {
          email_address: 'test@example.com',
          rx_flag: false
        }
        expect(preference.mhv_params).to eq(expected_params)
      end
    end

    context 'when invalid' do
      it 'raises ValidationErrors exception' do
        preference.email_address = 'invalid-email'
        expect { preference.mhv_params }.to raise_error(Common::Exceptions::ValidationErrors)
      end

      it 'raises ValidationErrors with the model instance' do
        preference.rx_flag = nil
        expect { preference.mhv_params }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::ValidationErrors)
          expect(error.resource).to eq(preference)
        end
      end
    end
  end

  describe '#id' do
    it 'returns a hex-formatted SHA256 digest' do
      id = preference.id
      expect(id).to be_a(String)
      expect(id.length).to eq(64) # SHA256 hex digest length
      expect(id).to match(/\A[a-f0-9]{64}\z/)
    end

    it 'returns consistent ID for same attributes' do
      preference1 = described_class.new(email_address: 'test@example.com', rx_flag: true)
      preference2 = described_class.new(email_address: 'test@example.com', rx_flag: true)

      expect(preference1.id).to eq(preference2.id)
    end

    it 'returns different IDs for different attributes' do
      preference1 = described_class.new(email_address: 'test1@example.com', rx_flag: true)
      preference2 = described_class.new(email_address: 'test2@example.com', rx_flag: true)

      expect(preference1.id).not_to eq(preference2.id)
    end

    it 'returns different IDs when rx_flag differs' do
      preference1 = described_class.new(email_address: 'test@example.com', rx_flag: true)
      preference2 = described_class.new(email_address: 'test@example.com', rx_flag: false)

      expect(preference1.id).not_to eq(preference2.id)
    end

    it 'handles nil attributes in ID generation' do
      preference_with_nils = described_class.new(email_address: nil, rx_flag: nil)
      expect { preference_with_nils.id }.not_to raise_error
      expect(preference_with_nils.id).to be_a(String)
      expect(preference_with_nils.id.length).to eq(64)
    end
  end

  describe 'integration scenarios' do
    it 'works end-to-end with valid data' do
      valid_preference = described_class.new(
        email_address: 'veteran@va.gov',
        rx_flag: true
      )

      expect(valid_preference).to be_valid
      expect(valid_preference.mhv_params).to eq({
                                                  email_address: 'veteran@va.gov',
                                                  rx_flag: true
                                                })
      expect(valid_preference.id).to be_a(String)
    end

    it 'properly handles edge case email formats' do
      edge_case_preference = described_class.new(
        email_address: 'test+prescriptions@subdomain.example.com',
        rx_flag: false
      )

      expect(edge_case_preference).to be_valid
      expect(edge_case_preference.mhv_params[:email_address]).to eq('test+prescriptions@subdomain.example.com')
    end
  end
end
