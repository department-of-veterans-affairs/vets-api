# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/formatters/base'

describe PdfFill::Forms::Formatters::Base do
  describe '#format_currency' do
    subject(:format_currency) do
      described_class.format_currency(value)
    end

    let(:value) { 10 }

    it 'converts to currency' do
      expect(format_currency).to eq '$10.00'
    end

    context 'decimals' do
      let(:value) { 100.43 }

      it 'displays formatted currency' do
        expect(format_currency).to eq '$100.43'
      end
    end

    context 'less than a dollar' do
      let(:value) { 0.22 }

      it 'displays formatted currency' do
        expect(format_currency).to eq '$0.22'
      end
    end

    context 'negative' do
      let(:value) { -100.22 }

      it 'displays formatted currency' do
        expect(format_currency).to eq '-$100.22'
      end
    end
  end
end
