# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va21p527ez'

def basic_class
  PdfFill::Forms::Va21p527ez.new({})
end

describe PdfFill::Forms::Va21p527ez do
  include SchemaMatchers

  let(:form_data) do
    get_fixture('pdf_fill/21P-527EZ/kitchen_sink')
  end

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2016-12-31 00:00:00 EDT' do
      expect(described_class.new(form_data).merge_fields.to_json).to eq(
        get_fixture('pdf_fill/21P-527EZ/merge_fields').to_json
      )
    end
  end

  describe '#build_date_range_string' do
    it 'builds date range string' do
      date_range = {
        'from' => '2020-08-01',
        'to' => '2020-09-01'
      }
      no_end_date = {
        'from' => '2020-08-01'
      }
      expect(described_class.new({}).build_date_range_string(date_range)).to eq('2020-08-01 - 2020-09-01')
      expect(described_class.new({}).build_date_range_string(no_end_date)).to eq('2020-08-01 - No End Date')
    end
  end

  describe '#to_checkbox_on_off' do
    it 'returns correct values' do
      expect(described_class.new({}).to_checkbox_on_off(true)).to eq(1)
      expect(described_class.new({}).to_checkbox_on_off(false)).to eq('Off')
    end
  end

  describe '#to_radio_yes_no' do
    it 'returns correct values' do
      expect(described_class.new({}).to_radio_yes_no(true)).to eq(0)
      expect(described_class.new({}).to_radio_yes_no(false)).to eq(1)
    end
  end
end
