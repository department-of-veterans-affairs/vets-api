# frozen_string_literal: true

require 'rails_helper'

describe Vet360::Exceptions do
  describe '.known_keys' do
    subject { described_class.instance.known_keys }

    it 'returns an array of Vet360 exception keys' do
      expect(subject).to be_a Array
    end

    it 'contains only downcased, Vet360 exception keys' do
      total_key_count  = subject.size
      keys_with_vet360 = subject.select { |key| key.include? 'vet360_' }.size

      expect(total_key_count).to eq keys_with_vet360
    end
  end
end
