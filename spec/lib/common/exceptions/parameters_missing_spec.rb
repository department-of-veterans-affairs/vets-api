# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::ParametersMissing do
  context 'with no attributes provided' do
    it do
      expect { described_class.new }
        .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
    end
  end

  context 'with param provided' do
    subject { described_class.new(%w[first_parameter second_parameter]) }

    it 'implements #errors which returns an array' do
      expect(subject.errors).to be_an(Array)
    end

    it 'the errors object has all relevant keys' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Missing parameter',
               detail: 'The required parameter "first_parameter", is missing',
               code: '108',
               status: '400')
    end
  end
end
