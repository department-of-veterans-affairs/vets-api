# frozen_string_literal: true

require 'rails_helper'

def basic_class
  Burials::PdfFill::Forms::Va21p530ez.new({})
end

describe Burials::PdfFill::Forms::Va21p530ez do
  before do
    allow(Flipper).to receive(:enabled?).with(:burial_pdf_form_alignment).and_return(false)
  end

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
          true, 'BurialExpenseResponsibility'
        ],
        { 'hasBurialExpenseResponsibility' => 'On', 'noBurialExpenseResponsibility' => nil }
      ],
      [
        [
          false, 'BurialExpenseResponsibility'
        ],
        { 'hasBurialExpenseResponsibility' => nil, 'noBurialExpenseResponsibility' => 'On' }
      ],
      [
        [
          nil, 'BurialExpenseResponsibility'
        ],
        { 'hasBurialExpenseResponsibility' => nil, 'noBurialExpenseResponsibility' => nil }
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

  describe '#merge_fields' do
    let(:fixture_path) { "#{Burials::MODULE_PATH}/spec/fixtures/pdf_fill/#{Burials::FORM_ID}" }

    it 'merges the right fields', run_at: '2024-03-21 00:00:00 EDT' do
      expected_path = "#{fixture_path}/kitchen_sink.json"
      actual_path = "#{fixture_path}/merge_fields.json"

      expected = described_class.new(JSON.parse(File.read(expected_path))).merge_fields
      actual = JSON.parse(File.read(actual_path))

      # Create a diff that is easy to read when expected/actual differ
      diff = Hashdiff.diff(expected, actual)

      expect(diff).to eq([])
    end

    it 'leaves benefit selections blank on pdf if unselected', run_at: '2024-03-21 00:00:00 EDT' do
      unselected_benefits_data = JSON.parse(
        File.read("#{fixture_path}/kitchen_sink.json")
      ).except(
        'burialExpenseResponsibility', 'plotExpenseResponsibility', 'transportationExpenses',
        'previouslyReceivedAllowance', 'govtContributions'
      )

      expected = JSON.parse(
        File.read("#{fixture_path}/merge_fields.json")
      ).except(
        'burialExpenseResponsibility', 'plotExpenseResponsibility', 'transportationExpenses',
        'previouslyReceivedAllowance', 'govtContributions', 'hasBurialExpenseResponsibility',
        'noBurialExpenseResponsibility', 'hasPlotExpenseResponsibility', 'noPlotExpenseResponsibility'
      )
      expected['hasTransportation'] = nil
      expected['hasGovtContributions'] = nil
      expected['hasPreviouslyReceivedAllowance'] = nil

      actual = described_class.new(unselected_benefits_data).merge_fields

      # Create a diff that is easy to read when expected/actual differ
      diff = Hashdiff.diff(expected, actual)

      expect(diff).to eq([])
    end
  end
end
