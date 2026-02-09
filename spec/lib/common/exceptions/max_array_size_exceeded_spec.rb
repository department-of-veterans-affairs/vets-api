# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::MaxArraySizeExceeded do
  context 'with no attributes provided' do
    it do
      expect { described_class.new }
        .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 3)')
    end
  end

  context 'with field, actual_size, and max_size provided' do
    subject { described_class.new('ids', 1002, 1000) }

    it 'implements #errors which returns an array' do
      expect(subject.errors).to be_an(Array)
    end

    it 'the errors object has all relevant keys' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Too many items submitted',
               detail: '"ids" cannot exceed 1000 items (submitted 1002)',
               code: '108',
               status: '400')
    end
  end
end
