# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IncomeAndAssets::Helpers do
  subject { dummy_class.new }

  let(:dummy_class) { Class.new { include IncomeAndAssets::Helpers } }

  describe '#format_date_to_mm_dd_yyyy' do
    it 'formats a valid date string' do
      expect(subject.format_date_to_mm_dd_yyyy('2024-06-01')).to eq('06/01/2024')
    end

    it 'returns nil for blank input' do
      expect(subject.format_date_to_mm_dd_yyyy('')).to be_nil
      expect(subject.format_date_to_mm_dd_yyyy(nil)).to be_nil
    end
  end

  describe '#split_currency_amount_sm' do
    it 'splits a small currency amount correctly' do
      result = subject.split_currency_amount_sm(12_345.67)
      expect(result).to eq({
                             'cents' => '67',
                             'dollars' => '345',
                             'thousands' => '12'
                           })
    end

    it 'returns empty hash for zero, nil, negative, or too large amounts' do
      expect(subject.split_currency_amount_sm(nil)).to eq({})
      expect(subject.split_currency_amount_sm(0)).to eq({})
      expect(subject.split_currency_amount_sm(-1)).to eq({})
      expect(subject.split_currency_amount_sm(1_000_000)).to eq({})
    end

    it 'returns empty hash if any field exceeds its length' do
      result = subject.split_currency_amount_sm(999_999.99, { 'dollars' => 2 })
      expect(result).to eq({})
    end
  end

  describe '#split_currency_amount_lg' do
    it 'splits a large currency amount correctly' do
      result = subject.split_currency_amount_lg(12_345_678.90)
      expect(result).to eq({
                             'cents' => '90',
                             'dollars' => '678',
                             'thousands' => '345',
                             'millions' => '12'
                           })
    end

    it 'returns empty hash for zero, nil, negative, or too large amounts' do
      expect(subject.split_currency_amount_lg(nil)).to eq({})
      expect(subject.split_currency_amount_lg(0)).to eq({})
      expect(subject.split_currency_amount_lg(-1)).to eq({})
      expect(subject.split_currency_amount_lg(99_999_999)).to eq({})
    end

    it 'returns empty hash if any field exceeds its length' do
      result = subject.split_currency_amount_lg(99_999_998.99, { 'thousands' => 2 })
      expect(result).to eq({})
    end
  end

  describe '#get_currency_field' do
    it 'pads value to field length' do
      arr = %w[12 345 678 90]
      expect(subject.get_currency_field(arr, -2, 5)).to eq('  678')
    end

    it 'returns nil if index out of bounds' do
      arr = %w[12 345]
      expect(subject.get_currency_field(arr, -4, 2)).to be_nil
    end
  end

  describe '#change_hash_to_string' do
    it 'joins hash values with spaces' do
      hash = { a: 'foo', b: 'bar', c: 'baz' }
      expect(subject.change_hash_to_string(hash)).to eq('foo bar baz')
    end

    it 'returns empty string for blank hash' do
      expect(subject.change_hash_to_string({})).to eq('')
      expect(subject.change_hash_to_string(nil)).to eq('')
    end
  end
end
