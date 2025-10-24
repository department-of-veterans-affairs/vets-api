# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IncreaseCompensation::Helpers do
  subject { dummy_class.new }

  let(:dummy_class) { Class.new { include IncreaseCompensation::Helpers } }

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
      expect(result).to eq({ 'cents' => '67', 'dollars' => '345', 'thousands' => '12' })
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
      expect(result).to eq({ 'cents' => '90', 'dollars' => '678', 'thousands' => '345', 'millions' => '12' })
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

  describe '#split_currency_amount_thousands' do
    it 'returns empty hash for zero, nil, negative, or too large amounts' do
      expect(subject.split_currency_amount_thousands(nil)).to eq({})
      expect(subject.split_currency_amount_thousands(-1)).to eq({})
      expect(subject.split_currency_amount_thousands(1_000_000)).to eq({})
    end

    it 'returns hash with 2 left spaced values if greater than 999' do
      expect(subject.split_currency_amount_thousands(1250)).to eq({ 'firstThree' => '  1', 'lastThree' => '250' })
    end

    it 'returns hash of 1 value if less than 1000' do
      expect(subject.split_currency_amount_thousands(500)).to eq({ 'lastThree' => '500' })
      expect(subject.split_currency_amount_thousands(0)).to eq({ 'lastThree' => '  0' })
    end
  end

  describe '#format_custom_boolean' do
    it 'returns Off' do
      expect(subject.format_custom_boolean(nil)).to eq('Off')
      expect(subject.format_custom_boolean('')).to eq('Off')
    end

    it 'returns YES or custom value' do
      expect(subject.format_custom_boolean(true)).to eq('YES')
      expect(subject.format_custom_boolean(true, 'YES, explain')).to eq('YES, explain')
    end

    it 'returns No or custom values' do
      expect(subject.format_custom_boolean(false)).to eq('NO')
      expect(subject.format_custom_boolean(false, 'YES', 'No, explain')).to eq('No, explain')
    end
  end

  describe '#two_line_overflow' do
    it 'returns {} if the string is blank' do
      expect(subject.two_line_overflow('', 'test', 8)).to eq({})
    end

    it 'returns hash of 2 lines if over limit' do
      expect(subject.two_line_overflow('Too long String', 'test',
                                       8)).to eq({ 'test1' => 'Too long', 'test2' => ' String' })
    end

    it 'return hash of 1 line if under limit' do
      expect(subject.two_line_overflow('Under Limit', 'test', 12)).to eq({ 'test1' => 'Under Limit' })
    end
  end

  describe '#map_date_range' do
    it 'splits the dates in a range into month,day,year' do
      dates = { 'from' => '2025-01-01', 'to' => '2025-02-02' }
      expect(subject.map_date_range(dates)).to eq(
        {
          'from' => {
            'month' => '01',
            'day' => '01',
            'year' => '2025'
          },
          'to' => {
            'month' => '02',
            'day' => '02',
            'year' => '2025'
          }
        }
      )
    end

    it 'returns {} if date range is nil or has no from date' do
      expect(subject.map_date_range({})).to eq({})
      expect(subject.map_date_range(nil)).to eq({})
    end
  end
end
