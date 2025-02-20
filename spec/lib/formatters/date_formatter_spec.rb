# frozen_string_literal: true

require 'rails_helper'
require 'formatters/date_formatter'

describe Formatters::DateFormatter do
  describe '.format_date' do
    subject { described_class.format_date(date, date_format) }

    let(:date) { '30-1-2020' }
    let(:date_format) { :iso8601 }

    context 'when input date is nil' do
      let(:date) { nil }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when input date is an arbitrary value that is not a date' do
      let(:date) { 'banana' }
      let(:expected_log) { "[Formatters/DateFormatter] Cannot parse given date: #{date}" }

      it 'logs to the Rails Logger error buffer' do
        expect(Rails.logger).to receive(:error).with(expected_log)
        subject
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when input date is a date object' do
      let(:date) { Date.parse('30-1-2020') }

      context 'and default format is given' do
        let(:date_format) { :iso8601 }
        let(:expected_formatted_date) { '2020-01-30' }

        it 'returns a string that represents a date parsed to iso8601 format' do
          expect(subject).to eq(expected_formatted_date)
        end
      end

      context 'and number_iso98601 format is given' do
        let(:date_format) { :number_iso8601 }
        let(:expected_formatted_date) { '20200130' }

        it 'returns a string that represents a date parsed to iso8601 with numbers only' do
          expect(subject).to eq(expected_formatted_date)
        end
      end

      context 'and datetime_iso8601 format is given' do
        let(:date_format) { :datetime_iso8601 }
        let(:expected_formatted_date) { '2020-01-30T00:00:00+00:00' }

        it 'returns a string that represents a date parsed to iso8601 with full datetime granularity' do
          expect(subject).to eq(expected_formatted_date)
        end
      end

      context 'and month_day_year format is given' do
        let(:date_format) { :month_day_year }
        let(:expected_formatted_date) { 'Jan 30, 2020' }

        it 'returns a string that represents a date parsed to a Month Date, Year format' do
          expect(subject).to eq(expected_formatted_date)
        end
      end
    end

    context 'when input date is a string object that represents a date' do
      let(:date) { '30-1-2020' }

      context 'and default format is given' do
        let(:date_format) { :iso8601 }
        let(:expected_formatted_date) { '2020-01-30' }

        it 'returns a string that represents a date parsed to iso8601 format' do
          expect(subject).to eq(expected_formatted_date)
        end
      end

      context 'and number_iso98601 format is given' do
        let(:date_format) { :number_iso8601 }
        let(:expected_formatted_date) { '20200130' }

        it 'returns a string that represents a date parsed to iso8601 with numbers only' do
          expect(subject).to eq(expected_formatted_date)
        end
      end

      context 'and datetime_iso8601 format is given' do
        let(:date_format) { :datetime_iso8601 }
        let(:expected_formatted_date) { '2020-01-30T00:00:00+00:00' }

        it 'returns a string that represents a date parsed to iso8601 with full datetime granularity' do
          expect(subject).to eq(expected_formatted_date)
        end
      end

      context 'and month_day_year format is given' do
        let(:date_format) { :month_day_year }
        let(:expected_formatted_date) { 'Jan 30, 2020' }

        it 'returns a string that represents a date parsed to a Month Date, Year format' do
          expect(subject).to eq(expected_formatted_date)
        end
      end
    end
  end
end
