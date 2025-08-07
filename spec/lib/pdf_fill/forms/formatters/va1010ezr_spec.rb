# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/formatters/va1010ezr'

describe PdfFill::Forms::Formatters::Va1010ezr do
  describe '#format_phone_number' do
    subject(:format_phone_number) do
      described_class.format_phone_number(value)
    end

    context 'with a blank value' do
      let(:value) { nil }

      it 'returns nil' do
        expect(format_phone_number).to be_nil
      end
    end

    context 'with a valid value' do
      let(:value) { '1234567890' }

      it 'formats phone number' do
        expect(format_phone_number).to eq('(123) 456-7890')
      end
    end
  end

  describe '#format_ssn' do
    subject(:format_ssn) do
      described_class.format_ssn(value)
    end

    context 'with a blank value' do
      let(:value) { nil }

      it 'returns nil' do
        expect(format_ssn).to be_nil
      end
    end

    context 'with a valid value' do
      let(:value) { '1234567890' }

      it 'formats ssn' do
        expect(format_ssn).to eq('123-45-6789')
      end
    end
  end
end
