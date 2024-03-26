# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va21p530v2'

def basic_class
  PdfFill::Forms::Va21p530v2.new({})
end

describe PdfFill::Forms::Va21p530v2 do
  let(:form_data) do
    {}
  end

  let(:new_form_class) do
    described_class.new(form_data)
  end

  def class_form_data
    new_form_class.instance_variable_get(:@form_data)
  end

  test_method(
    basic_class,
    'expand_checkbox',
    [
      [
        [
          true, 'GovtContribution'
        ],
        { 'hasGovtContribution' => 'YES', 'noGovtContribution' => nil }
      ],
      [
        [
          false, 'GovtContribution'
        ],
        { 'hasGovtContribution' => nil, 'noGovtContribution' => 'NO' }
      ],
      [
        [
          nil, 'GovtContribution'
        ],
        { 'hasGovtContribution' => nil, 'noGovtContribution' => nil }
      ]
    ]
  )

  test_method(
    basic_class,
    'split_phone',
    [
      [
        [{}, nil],
        nil
      ],
      [
        [
          { phone: '1112223333' },
          :phone
        ],
        { 'first' => '111', 'second' => '222', 'third' => '3333' }
      ]
    ]
  )

  describe '#convert_location_of_death' do
    subject do
      new_form_class.convert_location_of_death
    end

    context 'with no location of death' do
      it 'returns nil' do
        expect(subject).to eq(nil)
      end
    end

    context 'with a regular location of death' do
      let(:form_data) do
        {
          'locationOfDeath' => {
            'location' => 'nursingHomeUnpaid'
          }
        }
      end

      it 'returns the directly mapped location' do
        subject
        expect(class_form_data['locationOfDeath']['checkbox']).to eq({ 'nursingHomeUnpaid' => 'On' })
      end
    end

    context 'with a location needed for translation' do
      let(:form_data) do
        {
          'locationOfDeath' => {
            'location' => 'atHome'
          }
        }
      end

      it 'returns the directly mapped location' do
        subject
        expect(class_form_data['locationOfDeath']['checkbox']).to eq({ 'nursingHomeUnpaid' => 'On' })
      end
    end
  end

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2024-03-21 00:00:00 EDT' do
      expect(described_class.new(get_fixture('pdf_fill/21P-530V2/kitchen_sink')).merge_fields.to_json).to eq(
        get_fixture('pdf_fill/21P-530V2/merge_fields').to_json
      )
    end
  end
end
