# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::InvalidSortCriteria do
  context 'with no attributes provided' do
    it do
      expect { described_class.new }
        .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 2)')
    end
  end

  context 'with field provided' do
    subject { described_class.new('resource', 'sort_criteria') }

    it 'implements #errors which returns an array' do
      expect(subject.errors).to be_an(Array)
    end

    it 'the errors object has all relevant keys' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Invalid sort criteria',
               detail: '"sort_criteria" is not a valid sort criteria for "resource"',
               code: '106',
               status: '400')
    end
  end
end
