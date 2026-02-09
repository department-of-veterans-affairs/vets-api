# frozen_string_literal: true

require 'rails_helper'

describe Vass::DataEncryptor do
  subject { described_class }

  let(:data_encryptor) { subject.build }
  let(:pii_data) { '{"last_name":"Smith","dob":"1980-01-15"}' }
  let(:encryption_key) { SecureRandom.hex(32) }

  before do
    allow(Settings.vass).to receive(:data_encryption_key).and_return(encryption_key)
  end

  describe '.build' do
    it 'returns an instance of DataEncryptor' do
      expect(data_encryptor).to be_an_instance_of(Vass::DataEncryptor)
    end
  end

  describe '#encrypt' do
    context 'when data is a valid string' do
      it 'returns an encrypted string' do
        encrypted = data_encryptor.encrypt(pii_data)

        expect(encrypted).to be_present
        expect(encrypted).to be_a(String)
        expect(encrypted).not_to eq(pii_data)
      end

      it 'returns a different encrypted value on each call (due to nonce)' do
        encrypted1 = data_encryptor.encrypt(pii_data)
        encrypted2 = data_encryptor.encrypt(pii_data)

        # GCM mode uses a unique nonce for each encryption, so results differ
        expect(encrypted1).not_to eq(encrypted2)
      end

      it 'produces Base64-encoded output' do
        encrypted = data_encryptor.encrypt(pii_data)

        # Should be valid Base64 (not raise an error)
        expect { Base64.decode64(encrypted) }.not_to raise_error
      end
    end

    context 'when data is nil' do
      it 'returns nil' do
        expect(data_encryptor.encrypt(nil)).to be_nil
      end
    end

    context 'when data is empty string' do
      it 'returns empty string' do
        expect(data_encryptor.encrypt('')).to eq('')
      end
    end

    context 'when encryption fails' do
      before do
        allow_any_instance_of(ActiveSupport::MessageEncryptor).to receive(:encrypt_and_sign)
          .and_raise(StandardError.new('Encryption failure'))
      end

      it 'raises EncryptionError' do
        expect do
          data_encryptor.encrypt(pii_data)
        end.to raise_error(Vass::Errors::EncryptionError, /Failed to encrypt data/)
      end

      it 'logs the encryption failure' do
        allow(Rails.logger).to receive(:error).and_call_original
        expect(Rails.logger).to receive(:error)
          .with(a_string_including('"service":"vass"', '"action":"data_encryption_failed"'))
          .and_call_original

        expect { data_encryptor.encrypt(pii_data) }.to raise_error(Vass::Errors::EncryptionError)
      end
    end
  end

  describe '#decrypt' do
    let(:encrypted_data) { data_encryptor.encrypt(pii_data) }

    context 'when data is encrypted correctly' do
      it 'decrypts the data back to original value' do
        decrypted = data_encryptor.decrypt(encrypted_data)

        expect(decrypted).to eq(pii_data)
      end

      it 'handles multiple encrypt/decrypt cycles' do
        encrypted1 = data_encryptor.encrypt(pii_data)
        decrypted1 = data_encryptor.decrypt(encrypted1)

        encrypted2 = data_encryptor.encrypt(decrypted1)
        decrypted2 = data_encryptor.decrypt(encrypted2)

        expect(decrypted1).to eq(pii_data)
        expect(decrypted2).to eq(pii_data)
      end
    end

    context 'when encrypted_data is nil' do
      it 'returns nil' do
        expect(data_encryptor.decrypt(nil)).to be_nil
      end
    end

    context 'when encrypted_data is empty string' do
      it 'returns empty string' do
        expect(data_encryptor.decrypt('')).to eq('')
      end
    end

    context 'when decrypting plaintext data (backward compatibility)' do
      let(:plaintext_data) { '{"edipi":"1234567890","veteran_id":"vet-uuid-123"}' }

      it 'returns the plaintext data as-is' do
        result = data_encryptor.decrypt(plaintext_data)

        expect(result).to eq(plaintext_data)
      end

      it 'logs a warning about backward compatibility' do
        allow(Rails.logger).to receive(:warn).and_call_original
        expect(Rails.logger).to receive(:warn)
          .with(a_string_including('"service":"vass"', '"action":"data_decryption_backward_compat"'))
          .and_call_original

        data_encryptor.decrypt(plaintext_data)
      end
    end

    context 'when decrypting invalid encrypted data' do
      let(:invalid_encrypted) { 'invalid-base64-or-tampered-data!!!' }

      it 'returns the value as-is for backward compatibility' do
        result = data_encryptor.decrypt(invalid_encrypted)

        expect(result).to eq(invalid_encrypted)
      end
    end

    context 'when decryption fails with unexpected error' do
      before do
        allow_any_instance_of(ActiveSupport::MessageEncryptor).to receive(:decrypt_and_verify)
          .and_raise(ArgumentError.new('Unexpected decryption error'))
      end

      it 'raises DecryptionError' do
        expect do
          data_encryptor.decrypt('some-encrypted-data')
        end.to raise_error(Vass::Errors::DecryptionError, /Failed to decrypt data/)
      end

      it 'logs the decryption failure' do
        allow(Rails.logger).to receive(:error).and_call_original
        expect(Rails.logger).to receive(:error)
          .with(a_string_including('"service":"vass"', '"action":"data_decryption_failed"'))
          .and_call_original

        expect do
          data_encryptor.decrypt('some-encrypted-data')
        end.to raise_error(Vass::Errors::DecryptionError)
      end
    end
  end

  describe 'encryption key validation' do
    context 'when encryption key is missing' do
      before do
        allow(Settings.vass).to receive(:data_encryption_key).and_return(nil)
      end

      it 'raises ConfigurationError on encrypt' do
        expect do
          data_encryptor.encrypt(pii_data)
        end.to raise_error(Vass::Errors::ConfigurationError, /not configured/)
      end

      it 'raises ConfigurationError on decrypt' do
        expect do
          data_encryptor.decrypt('some-data')
        end.to raise_error(Vass::Errors::ConfigurationError, /not configured/)
      end
    end

    context 'when encryption key is blank string' do
      before do
        allow(Settings.vass).to receive(:data_encryption_key).and_return('')
      end

      it 'raises ConfigurationError' do
        expect do
          data_encryptor.encrypt(pii_data)
        end.to raise_error(Vass::Errors::ConfigurationError, /not configured/)
      end
    end

    context 'when encryption key is too short' do
      before do
        allow(Settings.vass).to receive(:data_encryption_key).and_return('short-key')
      end

      it 'raises ConfigurationError with too short message' do
        expect do
          data_encryptor.encrypt(pii_data)
        end.to raise_error(Vass::Errors::ConfigurationError, /too short/)
      end
    end
  end

  describe 'encryption integration' do
    it 'encrypts and decrypts complex JSON data' do
      complex_data = {
        edipi: '1234567890',
        veteran_id: 'vet-uuid-123',
        jti: SecureRandom.uuid,
        metadata: {
          timestamp: Time.now.to_i,
          source: 'vass'
        }
      }.to_json

      encrypted = data_encryptor.encrypt(complex_data)
      decrypted = data_encryptor.decrypt(encrypted)

      expect(decrypted).to eq(complex_data)
      expect(JSON.parse(decrypted)).to include('edipi', 'veteran_id', 'jti', 'metadata')
    end

    it 'ensures encrypted data does not contain plaintext' do
      sensitive_ssn = '123-45-6789'
      data = { ssn: sensitive_ssn }.to_json

      encrypted = data_encryptor.encrypt(data)

      expect(encrypted).not_to include(sensitive_ssn)
      expect(encrypted).not_to include('123')
      expect(encrypted).not_to include('6789')
    end
  end
end
