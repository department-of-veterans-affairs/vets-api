# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::InvalidResource do
  context 'with no resource provided' do
    it do
      expect { described_class.new }
        .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1..2)')
    end
  end

  context 'with valid resource provided' do
    subject { described_class.new('Prescription') }

    it 'implements #errors which returns an array' do
      expect(subject.errors).to be_an(Array)
    end

    it 'the errors object has all relevant keys' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Invalid resource',
               detail: 'Prescription is not a valid resource',
               code: '101',
               status: '400')
    end
  end

  context 'with valid resource provided and optional detail' do
    subject { described_class.new('Prescription', detail: 'optional details') }

    it 'implements #errors which returns an array' do
      expect(subject.errors).to be_an(Array)
    end

    it 'the errors object has all relevant keys' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Invalid resource',
               detail: 'optional details',
               code: '101',
               status: '400')
    end
  end
end
