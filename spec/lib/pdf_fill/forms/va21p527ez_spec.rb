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

  describe '#to_radio_yes_no' do
    it 'returns correct values' do
      expect(described_class.new({}).to_radio_yes_no(true)).to eq(0)
      expect(described_class.new({}).to_radio_yes_no(false)).to eq(1)
    end
  end

  describe '#to_checkbox_on_off' do
    it 'returns correct values' do
      expect(described_class.new({}).to_checkbox_on_off(true)).to eq(1)
      expect(described_class.new({}).to_checkbox_on_off(false)).to eq('Off')
    end
  end

  describe '#split_currency_amount' do
    it 'returns correct values' do
      expect(described_class.new({}).split_currency_amount(10_000_000)).to eq({})
      expect(described_class.new({}).split_currency_amount(-1)).to eq({})
      expect(described_class.new({}).split_currency_amount(nil)).to eq({})
      expect(described_class.new({}).split_currency_amount(100)).to eq({
                                                                         'part_one' => '100',
                                                                         'part_cents' => '00'
                                                                       })
      expect(described_class.new({}).split_currency_amount(999_888.77)).to eq({
                                                                                'part_two' => '999',
                                                                                'part_one' => '888',
                                                                                'part_cents' => '77'
                                                                              })
      expect(described_class.new({}).split_currency_amount(9_888_777.66)).to eq({
                                                                                  'part_three' => '9',
                                                                                  'part_two' => '888',
                                                                                  'part_one' => '777',
                                                                                  'part_cents' => '66'
                                                                                })
    end
  end
end
