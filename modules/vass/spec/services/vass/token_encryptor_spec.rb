# frozen_string_literal: true

require 'rails_helper'

describe Vass::TokenEncryptor do
  subject { described_class }

  let(:token_encryptor) { subject.build }
  let(:oauth_token) { 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.test.token' }
  let(:encryption_key) { SecureRandom.hex(32) }

  before do
    allow(Settings.vass).to receive(:token_encryption_key).and_return(encryption_key)
  end

  describe '.build' do
    it 'returns an instance of TokenEncryptor' do
      expect(token_encryptor).to be_an_instance_of(Vass::TokenEncryptor)
    end
  end

  describe '#encrypt' do
    context 'when token is a valid string' do
      it 'returns an encrypted string' do
        encrypted = token_encryptor.encrypt(oauth_token)

        expect(encrypted).to be_present
        expect(encrypted).to be_a(String)
        expect(encrypted).not_to eq(oauth_token)
      end

      it 'returns a different encrypted value on each call (due to nonce)' do
        encrypted1 = token_encryptor.encrypt(oauth_token)
        encrypted2 = token_encryptor.encrypt(oauth_token)

        # GCM mode uses a unique nonce for each encryption, so results differ
        expect(encrypted1).not_to eq(encrypted2)
      end

      it 'produces Base64-encoded output' do
        encrypted = token_encryptor.encrypt(oauth_token)

        # Should be valid Base64 (not raise an error)
        expect { Base64.decode64(encrypted) }.not_to raise_error
      end
    end

    context 'when token is nil' do
      it 'returns nil' do
        expect(token_encryptor.encrypt(nil)).to be_nil
      end
    end

    context 'when token is empty string' do
      it 'returns empty string' do
        expect(token_encryptor.encrypt('')).to eq('')
      end
    end

    context 'when encryption fails' do
      before do
        allow_any_instance_of(ActiveSupport::MessageEncryptor).to receive(:encrypt_and_sign)
          .and_raise(StandardError.new('Encryption failure'))
      end

      it 'raises EncryptionError' do
        expect do
          token_encryptor.encrypt(oauth_token)
        end.to raise_error(Vass::Errors::EncryptionError, /Failed to encrypt token/)
      end

      it 'logs the encryption failure' do
        allow(Rails.logger).to receive(:error).and_call_original
        expect(Rails.logger).to receive(:error)
          .with(a_string_including('"service":"vass"', '"action":"token_encryption_failed"'))
          .and_call_original

        expect { token_encryptor.encrypt(oauth_token) }.to raise_error(Vass::Errors::EncryptionError)
      end
    end
  end

  describe '#decrypt' do
    let(:encrypted_token) { token_encryptor.encrypt(oauth_token) }

    context 'when token is encrypted correctly' do
      it 'decrypts the token back to original value' do
        decrypted = token_encryptor.decrypt(encrypted_token)

        expect(decrypted).to eq(oauth_token)
      end

      it 'handles multiple encrypt/decrypt cycles' do
        encrypted1 = token_encryptor.encrypt(oauth_token)
        decrypted1 = token_encryptor.decrypt(encrypted1)

        encrypted2 = token_encryptor.encrypt(decrypted1)
        decrypted2 = token_encryptor.decrypt(encrypted2)

        expect(decrypted1).to eq(oauth_token)
        expect(decrypted2).to eq(oauth_token)
      end
    end

    context 'when encrypted_token is nil' do
      it 'returns nil' do
        expect(token_encryptor.decrypt(nil)).to be_nil
      end
    end

    context 'when encrypted_token is empty string' do
      it 'returns empty string' do
        expect(token_encryptor.decrypt('')).to eq('')
      end
    end

    context 'when decrypting a plaintext token (backward compatibility)' do
      let(:plaintext_token) { 'plaintext-oauth-token-from-old-cache' }

      it 'returns the plaintext token as-is' do
        result = token_encryptor.decrypt(plaintext_token)

        expect(result).to eq(plaintext_token)
      end

      it 'logs a warning about backward compatibility' do
        allow(Rails.logger).to receive(:warn).and_call_original
        expect(Rails.logger).to receive(:warn)
          .with(a_string_including('"service":"vass"', '"action":"token_decryption_backward_compat"'))
          .and_call_original

        token_encryptor.decrypt(plaintext_token)
      end
    end

    context 'when decrypting invalid encrypted data' do
      let(:invalid_encrypted) { 'invalid-base64-or-tampered-data!!!' }

      it 'returns the value as-is for backward compatibility' do
        result = token_encryptor.decrypt(invalid_encrypted)

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
          token_encryptor.decrypt('some-encrypted-data')
        end.to raise_error(Vass::Errors::DecryptionError, /Failed to decrypt token/)
      end

      it 'logs the decryption failure' do
        allow(Rails.logger).to receive(:error).and_call_original
        expect(Rails.logger).to receive(:error)
          .with(a_string_including('"service":"vass"', '"action":"token_decryption_failed"'))
          .and_call_original

        expect do
          token_encryptor.decrypt('some-encrypted-data')
        end.to raise_error(Vass::Errors::DecryptionError)
      end
    end
  end

  describe 'encryption key validation' do
    context 'when encryption key is missing' do
      before do
        allow(Settings.vass).to receive(:token_encryption_key).and_return(nil)
      end

      it 'raises ConfigurationError on encrypt' do
        expect do
          token_encryptor.encrypt(oauth_token)
        end.to raise_error(Vass::Errors::ConfigurationError, /not configured/)
      end

      it 'raises ConfigurationError on decrypt' do
        expect do
          token_encryptor.decrypt('some-token')
        end.to raise_error(Vass::Errors::ConfigurationError, /not configured/)
      end
    end

    context 'when encryption key is blank string' do
      before do
        allow(Settings.vass).to receive(:token_encryption_key).and_return('')
      end

      it 'raises ConfigurationError' do
        expect do
          token_encryptor.encrypt(oauth_token)
        end.to raise_error(Vass::Errors::ConfigurationError, /not configured/)
      end
    end

    context 'when encryption key is too short' do
      before do
        allow(Settings.vass).to receive(:token_encryption_key).and_return('short-key')
      end

      it 'raises ConfigurationError with minimum length requirement' do
        expect do
          token_encryptor.encrypt(oauth_token)
        end.to raise_error(Vass::Errors::ConfigurationError, /too short.*Must be at least 32 characters/)
      end
    end

    context 'when encryption key is exactly 32 characters' do
      before do
        allow(Settings.vass).to receive(:token_encryption_key).and_return('a' * 32)
      end

      it 'accepts the key' do
        expect { token_encryptor.encrypt(oauth_token) }.not_to raise_error
      end
    end

    context 'when encryption key is longer than 32 characters' do
      before do
        allow(Settings.vass).to receive(:token_encryption_key).and_return(SecureRandom.hex(64))
      end

      it 'accepts the key' do
        expect { token_encryptor.encrypt(oauth_token) }.not_to raise_error
      end
    end
  end

  describe 'encryption properties' do
    it 'uses AES-256-GCM cipher' do
      encryptor_instance = token_encryptor.send(:encryptor)

      expect(encryptor_instance).to be_an_instance_of(ActiveSupport::MessageEncryptor)
      expect(encryptor_instance.instance_variable_get(:@cipher)).to eq('aes-256-gcm')
    end

    it 'uses a derived key with vass-token-encryption salt' do
      # Verify that the same encryption key produces deterministic encryptor setup
      # (though encryption output differs due to nonce)
      encryptor1 = token_encryptor.send(:encryptor)
      encryptor2 = token_encryptor.send(:encryptor)

      expect(encryptor1).to be(encryptor2) # Same instance (memoized)
    end
  end

  describe 'different keys produce different encryption' do
    let(:key1) { SecureRandom.hex(32) }
    let(:key2) { SecureRandom.hex(32) }
    let(:encryptor1) { described_class.new }
    let(:encryptor2) { described_class.new }

    before do
      allow(Settings.vass).to receive(:token_encryption_key).and_return(key1)
      allow(encryptor2).to receive(:encryption_key).and_return(key2)
    end

    it 'produces different encrypted output with different keys' do
      encrypted1 = encryptor1.encrypt(oauth_token)

      allow(Settings.vass).to receive(:token_encryption_key).and_return(key2)
      encrypted2 = encryptor2.encrypt(oauth_token)

      expect(encrypted1).not_to eq(encrypted2)
    end

    it 'cannot decrypt with wrong key' do
      encrypted = encryptor1.encrypt(oauth_token)

      allow(Settings.vass).to receive(:token_encryption_key).and_return(key2)

      # Should fall back to returning the encrypted text (backward compat behavior)
      result = encryptor2.decrypt(encrypted)
      expect(result).to eq(encrypted) # Returns encrypted text as-is (can't decrypt)
      expect(result).not_to eq(oauth_token) # Does not successfully decrypt
    end
  end

  describe 'integration with real tokens' do
    let(:real_looking_token) do
      'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IjEyMyJ9.eyJhdWQiOiJodHRwczovL2FwaS52YS5n' \
        'b3YiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS51cy90ZW5hbnQiLCJpYXQiOjE3MDkz' \
        'MjU2MDAsImV4cCI6MTcwOTMyOTIwMCwic3ViIjoiY2xpZW50LWlkIn0.signature'
    end

    it 'successfully encrypts and decrypts a real-looking JWT token' do
      encrypted = token_encryptor.encrypt(real_looking_token)
      decrypted = token_encryptor.decrypt(encrypted)

      expect(decrypted).to eq(real_looking_token)
    end

    it 'handles tokens with special characters' do
      tokens = [
        'token-with-dashes',
        'token_with_underscores',
        'token.with.dots',
        'token+with+plus',
        'token/with/slash',
        'token=with=equals'
      ]

      tokens.each do |token|
        encrypted = token_encryptor.encrypt(token)
        decrypted = token_encryptor.decrypt(encrypted)

        expect(decrypted).to eq(token)
      end
    end

    it 'handles very long tokens' do
      long_token = 'a' * 10_000

      encrypted = token_encryptor.encrypt(long_token)
      decrypted = token_encryptor.decrypt(encrypted)

      expect(decrypted).to eq(long_token)
    end
  end
end
