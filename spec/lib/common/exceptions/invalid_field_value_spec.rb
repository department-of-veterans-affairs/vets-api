# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::InvalidFieldValue do
  context 'with no field provided' do
    it do
      expect { described_class.new }
        .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 2)')
    end
  end

  context 'with field provided' do
    subject { described_class.new('facility_name', 'invalid_value') }

    it 'implements #errors which returns an array' do
      expect(subject.errors).to be_an(Array)
    end

    it 'the errors object has all relevant keys' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Invalid field value',
               detail: '"invalid_value" is not a valid value for "facility_name"',
               code: '103',
               status: '400')
    end
  end
end
