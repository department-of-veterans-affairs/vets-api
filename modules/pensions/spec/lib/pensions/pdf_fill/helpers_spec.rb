# frozen_string_literal: true

require 'pensions/pdf_fill/helpers'

describe Pensions::PdfFill::Helpers do
  let(:helper_class) do
    Class.new do
      include Pensions::PdfFill::Helpers

      def initialize(data = {})
        @form_data = data
      end
    end
  end

  let(:helper) { helper_class.new({}) }

  describe '#to_radio_yes_no' do
    it 'returns correct values' do
      expect(helper.to_radio_yes_no(true)).to eq(0)
      expect(helper.to_radio_yes_no(false)).to eq(1)
    end
  end

  describe '#to_checkbox_on_off' do
    it 'returns correct values' do
      expect(helper.to_checkbox_on_off(true)).to eq('1')
      expect(helper.to_checkbox_on_off(false)).to eq('Off')
    end
  end

  describe '#split_currency_amount' do
    it 'returns correct values' do
      expect(helper.split_currency_amount(10_000_000)).to eq({})
      expect(helper.split_currency_amount(-1)).to eq({})
      expect(helper.split_currency_amount(nil)).to eq({})
      expect(helper.split_currency_amount(100)).to eq({
                                                        'part_one' => '100',
                                                        'part_cents' => '00'
                                                      })
      expect(helper.split_currency_amount(999_888.77)).to eq({
                                                               'part_two' => '999',
                                                               'part_one' => '888',
                                                               'part_cents' => '77'
                                                             })
      expect(helper.split_currency_amount(9_888_777.66)).to eq({
                                                                 'part_three' => '9',
                                                                 'part_two' => '888',
                                                                 'part_one' => '777',
                                                                 'part_cents' => '66'
                                                               })
    end
  end
end
