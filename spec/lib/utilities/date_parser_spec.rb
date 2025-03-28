# frozen_string_literal: true

require 'rails_helper'
require 'utilities/date_parser'

RSpec.describe Utilities::DateParser do
  describe '.parse' do
    subject { described_class.parse(date) }

    context 'when date is nil' do
      let(:date) { nil }

      it { is_expected.to be_nil }
    end

    context 'when date is blank' do
      let(:date) { '' }

      it { is_expected.to be_nil }
    end

    context 'when date is a DateTime' do
      let(:date) { DateTime.new(2020, 12, 25, 14, 30, 0, '+0000') }

      it { is_expected.to eq(date) }
    end

    context 'when date is a Time' do
      let(:date) { Time.new(2020, 12, 25, 14, 30, 0, '+0000') }

      it { is_expected.to eq(date.to_datetime) }
    end

    context 'when date is a Date' do
      let(:date) { Date.new(2020, 12, 25) }

      it 'converts to DateTime with current time components' do
        Timecop.freeze(Time.new(2020, 1, 1, 12, 30, 45, '+0000')) do
          expect(subject).to eq(DateTime.new(2020, 12, 25, 12, 30, 45))
        end
      end
    end

    context 'when date is a Hash' do
      let(:date) { { 'year' => '2020', 'month' => '12', 'day' => '25' } }

      it 'converts to DateTime with current time components' do
        Timecop.freeze(Time.new(2020, 1, 1, 12, 30, 45, '+0000')) do
          expect(subject).to eq(DateTime.new(2020, 12, 25, 12, 30, 45))
        end
      end
    end

    context 'when date is a String' do
      let(:date) { '2020-12-25T14:30:00Z' }

      it { is_expected.to eq(DateTime.parse(date)) }
    end

    context 'when date is invalid' do
      let(:date) { 'invalid date' }

      it { is_expected.to be_nil }
    end
  end
end
