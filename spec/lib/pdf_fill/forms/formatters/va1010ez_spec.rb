# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/formatters/va1010ez'

describe PdfFill::Forms::Formatters::Va1010ez do
  describe '#format_full_name' do
    subject(:format_full_name) do
      described_class.format_full_name(full_name)
    end

    let(:full_name_hash) do
      {
        'first' => 'Indiana',
        'middle' => 'Bill',
        'last' => 'Jones',
        'suffix' => 'II'
      }
    end

    let(:full_name) { full_name_hash }

    it 'formats full name' do
      expect(format_full_name).to eq('Jones, Indiana, Bill II')
    end

    context 'missing suffix' do
      let(:full_name) { full_name_hash.except('suffix') }

      it 'formats full name' do
        expect(format_full_name).to eq 'Jones, Indiana, Bill'
      end
    end

    context 'missing middle' do
      let(:full_name) { full_name_hash.except('middle') }

      it 'formats full name' do
        expect(format_full_name).to eq 'Jones, Indiana II'
      end
    end

    context 'missing middle and suffix' do
      let(:full_name) { full_name_hash.except('middle', 'suffix') }

      it 'formats full name' do
        expect(format_full_name).to eq 'Jones, Indiana'
      end
    end
  end

  describe '#format_date' do
    subject(:format_date) do
      described_class.format_date(date_string)
    end

    let(:date_string) { '1980-12-01' }

    it 'formats date' do
      expect(format_date).to eq('12/01/1980')
    end

    context 'date is MM/DD/YYYY format' do
      let(:date_string) { '12/01/1980' }

      it 'formats date' do
        expect(format_date).to eq date_string
      end
    end

    context 'date is YYYY-MM-XX format' do
      let(:date_string) { '1977-12-XX' }

      it 'formats date' do
        expect(format_date).to eq '12/1977'
      end
    end

    context 'invalid date string' do
      context 'date_string is empty string' do
        let(:date_string) { '' }

        it 'formats date' do
          expect(format_date).to be_nil
        end
      end

      context 'date_string is nil' do
        let(:date_string) { nil }

        it 'formats date' do
          expect(format_date).to be_nil
        end
      end

      context 'date_string is not a date' do
        let(:date_string) { 'not-a-date' }

        it 'formats date' do
          expect(Rails.logger).to receive(:error).with(
            "[#{described_class}] Unparseable date string", { date_string: }
          )
          expect(format_date).to eq date_string
        end
      end

      context 'date_string has invalid month' do
        let(:date_string) { '13/13/2020' }

        it 'formats date' do
          expect(Rails.logger).to receive(:error).with(
            "[#{described_class}] Unparseable date string", { date_string: }
          )
          expect(format_date).to eq date_string
        end
      end
    end
  end
end
