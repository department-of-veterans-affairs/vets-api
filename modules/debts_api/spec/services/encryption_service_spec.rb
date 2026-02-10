# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EncryptionService do
  describe '.encrypt' do
    it 'returns an encrypted string different from the original value' do
      value = 'sensitive data'
      encrypted = described_class.encrypt(value)

      expect(encrypted).to be_a(String)
      expect(encrypted).not_to eq(value)
      expect(encrypted).not_to be_blank
    end

    it 'encrypts hashes (e.g. PII payloads)' do
      value = { 'email' => 'user@example.com', 'first_name' => 'Jane' }
      encrypted = described_class.encrypt(value)

      expect(encrypted).to be_a(String)
      expect(encrypted).not_to include('user@example.com')
      expect(encrypted).not_to include('Jane')
    end
  end

  describe '.decrypt' do
    it 'decrypts a value previously encrypted by .encrypt' do
      original = 'secret message'
      encrypted = described_class.encrypt(original)
      decrypted = described_class.decrypt(encrypted)

      expect(decrypted).to eq(original)
    end

    it 'round-trips hashes correctly' do
      original = { 'email' => 'veteran@va.gov', 'first_name' => 'John' }
      encrypted = described_class.encrypt(original)
      decrypted = described_class.decrypt(encrypted)

      expect(decrypted).to eq(original)
    end

    it 'raises ActiveSupport::MessageEncryptor::InvalidMessage for tampered or invalid data' do
      expect { described_class.decrypt('not-valid-encrypted-data') }
        .to raise_error(ActiveSupport::MessageEncryptor::InvalidMessage)
    end

    it 'raises for nil or invalid input' do
      expect { described_class.decrypt(nil) }.to raise_error
    end
  end
end
