# frozen_string_literal: true

require 'rails_helper'
require 'vets/type/hash'

RSpec.describe Vets::Type::Hash do
  let(:name) { 'test_hash' }
  let(:hash_instance) { described_class.new(name) }

  describe '#cast' do
    context 'when value is nil' do
      it 'returns nil' do
        expect(hash_instance.cast(nil)).to be_nil
      end
    end

    context 'when value is a valid Hash' do
      let(:valid_hash) { { key: 'value' } }

      it 'returns the Hash' do
        expect(hash_instance.cast(valid_hash)).to eq(valid_hash)
      end
    end

    context 'when value is not a Hash' do
      let(:invalid_value) { 'string' }

      it 'raises a TypeError with the correct message' do
        expect do
          hash_instance.cast(invalid_value)
        end.to raise_error(TypeError, "#{name} must be a Hash")
      end
    end
  end
end
