# frozen_string_literal: true

require 'rails_helper'
require 'aes_256_cbc_encryptor'

describe VAOS::ReferralEncryptionService do
  let(:referral_id) { '12345abc' }
  let(:hex_secret) { 'EC121FF80513AE58ED478D5C5787075BF53C35733BFA55ABB18F323A3AD8EDE5' }
  let(:hex_iv) { '00ABEB85AB5C293F15DDF1647449A00C' }
  let(:encryption_stub) { OpenStruct.new(hex_secret:, hex_iv:) }
  let(:referral_stub) { OpenStruct.new(encryption: encryption_stub) }
  let(:vaos_stub) { OpenStruct.new(referral: referral_stub) }
  let(:encrypted_id) { described_class.encrypt(referral_id) }

  # Clear the thread-local encryptor between tests
  before do
    Thread.current[:vaos_referral_encryptor] = nil
    allow(Settings).to receive(:vaos).and_return(vaos_stub)
  end

  after { Thread.current[:vaos_referral_encryptor] = nil }

  describe '.encrypt' do
    it 'returns a URL-safe string' do
      expect(encrypted_id).to be_a(String)
      expect(encrypted_id).not_to include('+')
      expect(encrypted_id).not_to include('/')
      expect(encrypted_id).not_to include(referral_id)
    end

    it 'returns nil for blank input' do
      expect(described_class.encrypt(nil)).to be_nil
      expect(described_class.encrypt('')).to be_nil
    end
  end

  describe '.decrypt' do
    it 'decrypts the encrypted id back to the original value' do
      expect(described_class.decrypt(encrypted_id)).to eq(referral_id)
    end

    it 'returns nil for blank input' do
      expect(described_class.decrypt(nil)).to be_nil
      expect(described_class.decrypt('')).to be_nil
    end
  end

  describe '.encryptor' do
    it 'returns an instance of Aes256CbcEncryptor' do
      expect(described_class.encryptor).to be_a(Aes256CbcEncryptor)
    end

    it 'caches the encryptor instance per thread' do
      first_call = described_class.encryptor
      second_call = described_class.encryptor
      expect(first_call).to be(second_call)
      expect(Thread.current[:vaos_referral_encryptor]).to be(first_call)
    end
  end
end
