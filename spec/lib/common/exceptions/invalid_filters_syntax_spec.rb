# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::InvalidFiltersSyntax do
  context 'with no filters provided' do
    it do
      expect { described_class.new }
        .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1..2)')
    end
  end

  context 'with valid filters provided' do
    subject { described_class.new('facility_name' => 'ABC123') }

    it 'implements #errors which returns an array' do
      expect(subject.errors).to be_an(Array)
    end

    it 'the errors object has all relevant keys' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Invalid filters syntax',
               detail: '{"facility_name"=>"ABC123"} is not a valid syntax for filtering',
               code: '105',
               status: '400')
    end
  end
end
