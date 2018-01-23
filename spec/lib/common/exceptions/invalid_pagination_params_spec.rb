# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::InvalidPaginationParams do
  context 'with no pagination params provided' do
    it do
      expect { described_class.new }
        .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1..2)')
    end
  end

  context 'with pagination params provided' do
    let(:invalid_pagination_parms) { { 'page' => 'abc', 'per_page' => 10 } }
    subject { described_class.new(invalid_pagination_parms) }

    it 'implements #errors which returns an array' do
      expect(subject.errors).to be_an(Array)
    end

    it 'the errors object has all relevant keys' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Invalid pagination params',
               detail: "#{invalid_pagination_parms} are invalid",
               code: '107',
               status: '400')
    end
  end

  context 'with pagination params provided and optional detail' do
    let(:invalid_pagination_parms) { { 'page' => 'abc', 'per_page' => 10 } }
    subject { described_class.new(invalid_pagination_parms, detail: 'optional details') }

    it 'implements #errors which returns an array' do
      expect(subject.errors).to be_an(Array)
    end

    it 'the errors object has all relevant keys' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Invalid pagination params',
               detail: 'optional details',
               code: '107',
               status: '400')
    end
  end
end
