# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::FilterNotAllowed do
  context 'with no filter provided' do
    it do
      expect { described_class.new }
        .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
    end
  end

  context 'with filter provided' do
    subject { described_class.new('facility_name') }

    it 'implements #errors which returns an array' do
      expect(subject.errors).to be_an(Array)
    end

    it 'the errors object has all relevant keys' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Filter not allowed',
               detail: '"facility_name" is not allowed for filtering',
               code: '104',
               status: '400')
    end
  end
end
