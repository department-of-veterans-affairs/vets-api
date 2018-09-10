# frozen_string_literal: true

require 'rails_helper'
require 'aes_256_cbc_encryptor'

describe Aes256CbcEncryptor do
  let(:hex_secret)       { 'EC121FF80513AE58ED478D5C5787075BF53C35733BFA55ABB18F323A3AD8EDE5' }
  let(:hex_iv)           { '00ABEB85AB5C293F15DDF1647449A00C' }
  subject { described_class.new(hex_secret, hex_iv) }

  context 'it right pads short secrets and iv' do
    let(:hex_secret) { 'EC121FF80513AE58ED478D5C5787075BF53C35733B' }
    let(:hex_iv)     { '00ABEB85AB5C2' }

    it 'returns a secret that is the correct length of 32 bytes' do
      expect(subject.secret.length).to eq(32)
    end

    it 'returns an iv that is the correct length of 16 bytes' do
      expect(subject.iv.length).to eq(16)
    end
  end

  it 'handles encryption' do
    expect(subject.encrypt('Hello World!')).to eq('nTPvvkd8vs3wt0EheNnr6w==')
  end

  it 'handles decryption' do
    expect(subject.decrypt('nTPvvkd8vs3wt0EheNnr6w==')).to eq('Hello World!')
  end
end
