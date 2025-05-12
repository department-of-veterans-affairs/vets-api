# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MPI::Type::ProfileAddress do
  subject(:type) { described_class.new }

  let(:valid_hash) do
    {
      street: '123 Main St',
      street2: 'Apt 4B',
      city: 'Denver',
      state: 'CO',
      postal_code: '80202',
      country: 'USA'
    }
  end

  let(:mvi_profile_address) { MPI::Models::MviProfileAddress.new(valid_hash) }

  describe '#cast' do
    context 'when given an MviProfileAddress instance' do
      it 'returns the same instance' do
        expect(type.cast(mvi_profile_address)).to eq(mvi_profile_address)
      end
    end
  end

  context 'when given a hash' do
    it 'returns a new MviProfileAddress instance with the hash attributes' do
      result = type.cast(valid_hash)
      expect(result).to be_a(MPI::Models::MviProfileAddress)
      expect(result.street).to eq('123 Main St')
      expect(result.street2).to eq('Apt 4B')
      expect(result.city).to eq('Denver')
      expect(result.state).to eq('CO')
      expect(result.postal_code).to eq('80202')
      expect(result.country).to eq('USA')
    end
  end

  context 'when given an invalid type' do
    it 'returns nil' do
      expect(type.cast('invalid')).to be_nil
    end
  end
end
