# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::InvalidField do
  context 'with no field provided' do
    it do
      expect { described_class.new }
        .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 2)')
    end
  end

  context 'with field provided' do
    subject { described_class.new('facility_name', 'Tracking') }

    it 'implements #errors which returns an array' do
      expect(subject.errors).to be_an(Array)
    end

    it 'the errors object has all relevant keys' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Invalid field',
               detail: '"facility_name" is not a valid field for "Tracking"',
               code: '102',
               status: '400')
    end
  end
end
