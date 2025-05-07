# frozen_string_literal: true

require 'rails_helper'

def basic_class
  Burials::PdfFill::Va21p530ez.new({})
end

describe Burials::PdfFill::Va21p530ez do
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
      ],
      [
        [
          { phone: '111-222-3333' },
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
        expect(subject).to be_nil
      end
    end

    context 'with a regular location of death in new format' do
      let(:form_data) do
        {
          'locationOfDeath' => {
            'location' => 'nursingHomeUnpaid'
          },
          'nursingHomeUnpaid' => {
            'facilityName' => 'facility name',
            'facilityLocation' => 'Washington, DC'
          }
        }
      end

      it 'returns the directly mapped location' do
        subject
        expect(class_form_data['locationOfDeath']['checkbox']).to eq({ 'nursingHomeUnpaid' => 'On' })
        expect(class_form_data['locationOfDeath']['placeAndLocation']).to eq('facility name - Washington, DC')
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

  describe 'set_state_to_no_if_national' do
    subject do
      new_form_class.set_state_to_no_if_national
    end

    context 'with a regular location of death' do
      let(:form_data) do
        {
          'nationalOrFederal' => true
        }
      end

      it 'returns the directly mapped location' do
        subject
        expect(class_form_data['cemetaryLocationQuestion']).to eq('none')
      end
    end
  end

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2024-03-21 00:00:00 EDT' do
      expect(described_class.new(
        JSON.parse(File.read(
                     "#{Burials::MODULE_PATH}/spec/fixtures/pdf_fill/#{Burials::FORM_ID}/kitchen_sink.json"
                   ))
      ).merge_fields.to_json).to eq(
        JSON.parse(File.read(
                     "#{Burials::MODULE_PATH}/spec/fixtures/pdf_fill/#{Burials::FORM_ID}/merge_fields.json"
                   )).to_json
      )
    end

    it 'leaves benefit selections blank on pdf if unselected', run_at: '2024-03-21 00:00:00 EDT' do
      unselected_benefits_data = JSON.parse(
        File.read("#{Burials::MODULE_PATH}/spec/fixtures/pdf_fill/#{Burials::FORM_ID}/kitchen_sink.json")
      ).except(
        'burialExpenseResponsibility', 'plotExpenseResponsibility', 'transportation'
      )

      expected_merge_data = JSON.parse(
        File.read("#{Burials::MODULE_PATH}/spec/fixtures/pdf_fill/#{Burials::FORM_ID}/merge_fields.json")
      ).except(
        'burialExpenseResponsibility', 'plotExpenseResponsibility', 'transportation'
      )
      expected_merge_data['hasTransportation'] = nil
      expected_merge_data['hasBurialExpenseResponsibility'] = nil
      expected_merge_data['hasPlotExpenseResponsibility'] = nil
      expect(described_class.new(unselected_benefits_data).merge_fields.to_json).to eq(
        expected_merge_data.to_json
      )
    end
  end
end
