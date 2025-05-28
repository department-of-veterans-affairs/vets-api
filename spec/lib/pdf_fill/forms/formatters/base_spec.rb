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

  describe '#format_facility_label' do
    subject(:format_facility_label) do
      described_class.format_facility_label(value)
    end

    before do
      create(:health_facility, name: 'VA Facility Name',
                               station_number: '100',
                               postal_name: 'OH')
    end

    context 'value is not in health_facilities table' do
      let(:value) { '99' }

      it 'returns the value' do
        expect(format_facility_label).to eq '99'
      end
    end

    context 'value is in health_facilities table' do
      let(:value) { '100' }

      it 'returns facility id and facility name' do
        expect(format_facility_label).to eq '100 - VA Facility Name'
      end
    end
  end
end
