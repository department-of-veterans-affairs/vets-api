# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/exceptions/parser'

describe VAProfile::Exceptions::Parser do
  describe '#known_keys' do
    subject { described_class.instance.known_keys }

    it 'returns an array of VAProfile exception keys' do
      expect(subject).to be_a Array
    end

    it 'contains only downcased, VAProfile exception keys' do
      total_key_count  = subject.size
      keys_with_vet360 = subject.select { |key| key.include? 'vet360_' }.size

      expect(total_key_count).to eq keys_with_vet360
    end
  end

  describe '#known?' do
    subject { described_class.instance }

    let(:known_key) { 'VET360_ADDR133' }
    let(:unknown_key) { 'VET360_some_key' }

    it 'returns true if the passed VAProfile exception key is present in the exception_keys' do
      expect(subject.known?(known_key)).to be true
    end

    it 'returns false if the passed VAProfile exception key is not present in the exception_keys' do
      expect(subject.known?(unknown_key)).to be false
    end
  end
end
