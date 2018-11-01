# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::NotASafeHostError do
  context 'with no attributes provided' do
    it do
      expect { described_class.new }
        .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
    end
  end

  context 'with host provided' do
    subject { described_class.new('unsafe_host') }

    it 'implements #errors which returns an array' do
      expect(subject.errors).to be_an(Array)
    end

    it 'the errors object has all relevant keys' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Bad Request',
               detail: '"unsafe_host" is not a safe host',
               code: '110',
               status: '400')
    end
  end
end
