# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::RecordNotFound do
  context 'with no resource provided' do
    it do
      expect { described_class.new }
        .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
    end
  end

  context 'with valid resource provided' do
    subject { described_class.new(12_345_678) }

    it 'implements #errors which returns an array' do
      expect(subject.errors).to be_an(Array)
    end

    it 'the errors object has all relevant keys' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Record not found',
               detail: 'The record identified by 12345678 could not be found',
               code: '404',
               status: '404')
    end
  end
end
