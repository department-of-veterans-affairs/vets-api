# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::DateUtils do
  describe '.valid_datetime?' do
    context 'with valid datetime strings' do
      it 'returns true for ISO 8601 format' do
        expect(described_class.valid_datetime?('2024-10-17T09:00:00Z')).to be(true)
        expect(described_class.valid_datetime?('2024-10-17T09:00:00-07:00')).to be(true)
        expect(described_class.valid_datetime?('2024-10-17T09:00:00+05:30')).to be(true)
      end

      it 'returns true for datetime with fractional seconds' do
        expect(described_class.valid_datetime?('2024-10-17T09:00:00.123Z')).to be(true)
        expect(described_class.valid_datetime?('2024-10-17T09:00:00.123456Z')).to be(true)
      end
    end

    context 'with valid Time objects' do
      it 'returns true for Time instances' do
        time = Time.zone.now
        expect(described_class.valid_datetime?(time)).to be(true)
      end

      it 'returns true for DateTime instances' do
        datetime = DateTime.now
        expect(described_class.valid_datetime?(datetime)).to be(true)
      end

      it 'returns true for Date instances' do
        date = Time.zone.today
        expect(described_class.valid_datetime?(date)).to be(true)
      end
    end

    context 'with invalid datetime strings' do
      it 'returns false for completely invalid strings' do
        expect(described_class.valid_datetime?('ITS A BANANA')).to be(false)
        expect(described_class.valid_datetime?('not a date')).to be(false)
        expect(described_class.valid_datetime?('Unable to convert UTC to local time')).to be(false)
        expect(described_class.valid_datetime?('hello world')).to be(false)
      end

      it 'returns false for invalid date components' do
        expect(described_class.valid_datetime?('2024-13-45T99:99:99Z')).to be(false)
        expect(described_class.valid_datetime?('2024-02-30T12:00:00Z')).to be(false)
        expect(described_class.valid_datetime?('2024-04-31T12:00:00Z')).to be(false)
        expect(described_class.valid_datetime?('2024-00-15T12:00:00Z')).to be(false)
      end
    end

    context 'with edge case inputs' do
      it 'returns false for nil' do
        expect(described_class.valid_datetime?(nil)).to be(false)
      end

      it 'returns false for empty string' do
        expect(described_class.valid_datetime?('')).to be(false)
      end

      it 'returns false for whitespace-only string' do
        expect(described_class.valid_datetime?('   ')).to be(false)
        expect(described_class.valid_datetime?("\n\t")).to be(false)
      end

      it 'returns false for numeric inputs' do
        expect(described_class.valid_datetime?(123_456)).to be(false)
        expect(described_class.valid_datetime?(0)).to be(false)
        expect(described_class.valid_datetime?(-1)).to be(false)
        expect(described_class.valid_datetime?(1.5)).to be(false)
      end

      it 'returns false for boolean inputs' do
        expect(described_class.valid_datetime?(true)).to be(false)
        expect(described_class.valid_datetime?(false)).to be(false)
      end

      it 'returns false for array and hash inputs' do
        expect(described_class.valid_datetime?([])).to be(false)
        expect(described_class.valid_datetime?([1, 2, 3])).to be(false)
        expect(described_class.valid_datetime?({})).to be(false)
      end

      it 'returns false for symbol inputs' do
        expect(described_class.valid_datetime?(:symbol)).to be(false)
        expect(described_class.valid_datetime?(:date)).to be(false)
      end
    end

    context 'with real-world appointment date examples' do
      it 'returns true for typical VAOS appointment date formats' do
        expect(described_class.valid_datetime?('2024-10-17T09:00:00-0700')).to be(true)
        expect(described_class.valid_datetime?('2021-05-20T14:10:00Z')).to be(true)
        expect(described_class.valid_datetime?('2021-06-02T16:00:00.000-0400')).to be(true)
      end
    end
  end
end
