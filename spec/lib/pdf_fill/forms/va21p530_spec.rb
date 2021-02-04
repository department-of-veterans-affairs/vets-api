# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va21p530'

def basic_class
  PdfFill::Forms::Va21p530.new({})
end

describe PdfFill::Forms::Va21p530 do
  let(:form_data) do
    {}
  end

  let(:new_form_class) do
    described_class.new(form_data)
  end

  def class_form_data
    new_form_class.instance_variable_get(:@form_data)
  end

  describe '#expand_firm' do
    context 'isEntity not set' do
      it 'does nothing' do
        new_form_class.expand_firm
        expect(class_form_data['firmNameAndAddr']).to eq(nil)
      end
    end

    context 'isEntity is true' do
      let(:form_data) do
        {
          'relationship' => {
            'isEntity' => true
          },
          'claimantAddress' => {
            'city' => 'Baltimore',
            'country' => 'USA',
            'postalCode' => {
              'firstFive' => '21231',
              'lastFour' => '1234'
            },
            'street' => 'street',
            'street2' => 'street2',
            'state' => 'MD'
          },
          'firmName' => 'firmName'
        }
      end

      it 'combines the firm name and addr' do
        new_form_class.expand_firm

        expect(
          JSON.parse(class_form_data['firmNameAndAddr'].to_json)
        ).to eq(
          'value' => 'firmName, street, street2, Baltimore, MD, 21231-1234, USA',
          'extras_value' => "firmName\nstreet\nstreet2\nBaltimore, MD, 21231-1234\nUSA"
        )
      end
    end
  end

  test_method(
    basic_class,
    'expand_relationship',
    [
      [
        [{}, nil],
        nil
      ],
      [
        [
          {
            rel: {
              'type' => 'foo'
            }
          },
          :rel
        ],
        { 'foo' => true }
      ]
    ]
  )

  test_method(
    basic_class,
    'expand_tours_of_duty',
    [
      [
        [nil],
        nil
      ],
      [
        [[{
          'dateRange' => {
            'from' => '2012-06-01',
            'to' => '2013-07-01'
          },
          'serviceBranch' => 'army1',
          'rank' => 'rank1',
          'serviceNumber' => 'sn1',
          'placeOfEntry' => 'placeOfEntry1',
          'placeOfSeparation' => 'place1'
        }]],
        [{ 'serviceBranch' => 'army1',
           'rank' => 'army1, rank1',
           'serviceNumber' => 'sn1',
           'placeOfEntry' => 'placeOfEntry1',
           'placeOfSeparation' => 'place1',
           'dateRangeStart' => '2012-06-01',
           'dateRangeEnd' => '2013-07-01' }]
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
    it 'merges the right fields', run_at: '2016-12-31 00:00:00 EDT' do
      expect(described_class.new(get_fixture('pdf_fill/21P-530/kitchen_sink')).merge_fields.to_json).to eq(
        get_fixture('pdf_fill/21P-530/merge_fields').to_json
      )
    end
  end
end
