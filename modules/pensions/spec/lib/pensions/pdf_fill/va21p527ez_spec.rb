# frozen_string_literal: true

require 'rails_helper'
require 'pensions/pdf_fill/va21p527ez'
require 'lib/pdf_fill/fill_form_examples'

def basic_class
  Pensions::PdfFill::Va21p527ez.new({})
end

describe Pensions::PdfFill::Va21p527ez do
  include SchemaMatchers

  let(:form_data) do
    VetsJsonSchema::EXAMPLES.fetch('21P-527EZ-KITCHEN_SINK')
  end

  it_behaves_like 'a form filler', {
    form_id: described_class::FORM_ID,
    factory: :pensions_saved_claim,
    use_vets_json_schema: true,
    input_data_fixture_dir: 'modules/pensions/spec/fixtures',
    output_pdf_fixture_dir: 'modules/pensions/spec/fixtures',
    fill_options: { extras_redesign: true, omit_esign_stamp: true }
  }

  describe '#merge_fields' do
    it 'merges the right fields' do
      Timecop.freeze(Time.zone.parse('2016-12-31 00:00:00 EDT')) do
        expected = get_fixture_absolute("#{Pensions::MODULE_PATH}/spec/fixtures/merge_fields")
        actual = described_class.new(form_data).merge_fields

        # Create a diff that is easy to read when expected/actual differ
        diff = Hashdiff.diff(expected, actual)

        expect(diff).to eq([])
      end
    ensure
      Timecop.return
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
      expect(described_class.new({}).to_checkbox_on_off(true)).to eq('1')
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

  describe '#marital_status_to_radio' do
    it 'returns correct radio value for marital status' do
      expect(described_class.new({}).marital_status_to_radio('MARRIED')).to eq(0)
      expect(described_class.new({}).marital_status_to_radio('SEPARATED')).to eq(1)
      expect(described_class.new({}).marital_status_to_radio('SINGLE')).to eq(2)
    end
  end

  describe '#reason_for_current_separation_to_radio' do
    it 'returns correct radio value for current separation reasons' do
      expect(described_class.new({}).reason_for_current_separation_to_radio('MEDICAL_CARE')).to eq(0)
      expect(described_class.new({}).reason_for_current_separation_to_radio('RELATIONSHIP')).to eq(1)
      expect(described_class.new({}).reason_for_current_separation_to_radio('LOCATION')).to eq(2)
      expect(described_class.new({}).reason_for_current_separation_to_radio('OTHER')).to eq(3)
      expect(described_class.new({}).reason_for_current_separation_to_radio('')).to eq('Off')
    end
  end

  describe '#expand_veteran_service_information' do
    it 'puts overflow on line one' do
      long_place_of_separation = 'A very long place name that exceeds thirty-six characters'
      form_data = { 'placeOfSeparation' => long_place_of_separation }
      form = described_class.new(form_data)
      form.expand_veteran_service_information
      updated_data = form.instance_variable_get('@form_data')

      expect(updated_data['placeOfSeparationLineOne']).to eq(long_place_of_separation)
    end
  end
end
