# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va21p527ezare'

def basic_class
  PdfFill::Forms::Va21p527ezare.new({})
end

describe PdfFill::Forms::Va21p527ezare do
  include SchemaMatchers

  let(:form_data) do
    get_fixture('pdf_fill/21P-527EZ-ARE/kitchen_sink')
  end

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2016-12-31 00:00:00 EDT' do
      expect(described_class.new(form_data).merge_fields.to_json).to eq(
        get_fixture('pdf_fill/21P-527EZ-ARE/merge_fields').to_json
      )
    end
  end

  describe '#to_radio_yes_no' do
    it 'returns correct values' do
      expect(described_class.new({}).to_radio_yes_no(true)).to eq(0)
      expect(described_class.new({}).to_radio_yes_no(false)).to eq(2)
    end
  end

  describe '#expand_service_period' do
    subject do
      described_class.new({}).expand_service_period(service_period)
    end

    let(:service_period) do
      {
        'serviceBranch' => 'Coast Guard',
        'activeServiceDateRange' => {
          'from' => '2020-12-12',
          'to' => '2022-12-12'
        },
        'serviceNumber' => '12345'
      }
    end

    it 'expands service periods' do
      expect(subject).to eq({
                              'activeServiceDateRange' => {
                                'from' => {
                                  'month' => '12',
                                  'day' => '12',
                                  'year' => '2020'
                                },
                                'to' => {
                                  'month' => '12',
                                  'day' => '12',
                                  'year' => '2022'
                                }
                              },
                              'serviceBranch' => {
                                'army' => false,
                                'navy' => false,
                                'airForce' => false,
                                'coastGuard' => true,
                                'marineCorps' => false,
                                'spaceForce' => false,
                                'usphs' => false,
                                'noaa' => false
                              },
                              'activeServiceDateRangeFromOverflow' => '2020-12-12',
                              'activeServiceDateRangeToOverflow' => '2022-12-12',
                              'serviceBranchOverflow' => 'Coast Guard'
                            })
    end
  end
end
