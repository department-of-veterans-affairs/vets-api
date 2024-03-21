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
        { "hasGovtContribution" => "YES", "noGovtContribution" => nil }
      ],
      [
        [
          false, 'GovtContribution'
        ],
        { "hasGovtContribution" => nil, "noGovtContribution" => "NO" }
      ],
      [
        [
          nil, 'GovtContribution'
        ],
        { "hasGovtContribution" => nil, "noGovtContribution" => nil }
      ],
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

  describe '#expand_place_of_death' do
    subject do
      new_form_class.expand_place_of_death
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
            'location' => 'vaMedicalCenter'
          }
        }
      end

      it 'returns the translated location' do
        expect(subject).to eq('VA MEDICAL CENTER')
      end
    end

    context 'with a custom location of death' do
      let(:form_data) do
        {
          'locationOfDeath' => {
            'location' => 'other',
            'other' => 'foo'
          }
        }
      end

      it 'returns the translated location' do
        expect(subject).to eq('foo')
      end
    end
  end

  describe '#expand_burial_allowance' do
    subject do
      new_form_class.expand_burial_allowance
    end

    context 'with no burial allowance' do
      it 'returns nil' do
        expect(subject).to eq(nil)
      end
    end

    context 'with a burial allowance' do
      let(:form_data) do
        {
          'burialAllowanceRequested' => 'foo'
        }
      end

      it 'expands the checkbox' do
        subject

        expect(class_form_data).to eq(
          'burialAllowanceRequested' => { 'value' => 'foo', 'checkbox' => { 'foo' => true } }
        )
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
