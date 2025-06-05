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
    output_pdf_fixture_dir: 'modules/pensions/spec/fixtures'
  }

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2016-12-31 00:00:00 EDT' do
      expect(described_class.new(form_data).merge_fields.to_json).to eq(
        get_fixture_absolute("#{Pensions::MODULE_PATH}/spec/fixtures/merge_fields").to_json
      )
    end
  end

  describe '#to_radio_yes_no' do
    it 'returns correct values' do
      expect(described_class.new({}).to_radio_yes_no(true)).to eq(1)
      expect(described_class.new({}).to_radio_yes_no(false)).to eq(2)
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

  describe '#expand_dependent_children' do
    it 'handles partially removed dependents' do
      form_data = {
        'dependents' => [
          {
            'childAddress' => {
              'country' => 'US',
              'city' => 'Cityville',
              'street' => '100 Main St',
              'state' => 'PA',
              'postalCode' => '11111'
            },
            'personWhoLivesWithChild' => {
              'last' => 'John',
              'first' => 'Smith'
            },
            'monthlyPayment' => 1200
          }
        ]
      }
      form = described_class.new(form_data)
      form.expand_dependent_children
      updated_data = form.instance_variable_get('@form_data')
      expect(updated_data['dependents'].length).to eq(1)
      expect(updated_data['custodians'].length).to eq(1)
      expect(updated_data['dependentChildrenInHousehold']).to eq('0')
      expect(updated_data['dependentsNotWithYouAtSameAddress']).to eq(1)
    end

    it 'handles overflow for dependent children not in the same household' do
      form_data = {
        'dependents' => [
          {
            'childAddress' => {
              'country' => 'US',
              'city' => 'Cityville',
              'street' => '100 Main St',
              'state' => 'PA',
              'postalCode' => '11111'
            },
            'childInHousehold' => false,
            'fullName' => {
              'first' => 'John',
              'middle' => 'A',
              'last' => 'Smith'
            },
            'personWhoLivesWithChild' => {
              'first' => 'Jane',
              'last' => 'Doe'
            },
            'monthlyPayment' => 500
          },
          {
            'childAddress' => {
              'country' => 'US',
              'city' => 'Cityville',
              'street' => '100 Main St',
              'state' => 'PA',
              'postalCode' => '11111'
            },
            'childInHousehold' => false,
            'fullName' => {
              'first' => 'Alice',
              'middle' => 'B',
              'last' => 'Johnson'
            },
            'personWhoLivesWithChild' => {
              'first' => 'Jane',
              'last' => 'Doe'
            },
            'monthlyPayment' => 700
          }
        ]
      }
      form = described_class.new(form_data)
      form.expand_dependent_children
      updated_data = form.instance_variable_get('@form_data')

      expect(updated_data['custodians'][0]['dependentsWithCustodianOverflow']).to eq('John A Smith, Alice B Johnson')
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

  describe '#expand_direct_deposit_information' do
    it 'sets correct account type' do
      form_data = { 'bankAccount' => { 'accountType' => 'checking' } }
      form = described_class.new(form_data)
      form.expand_direct_deposit_information
      expect(form.instance_variable_get('@form_data')['bankAccount']['accountType']).to eq(0)

      form_data = { 'bankAccount' => { 'accountType' => 'savings' } }
      form = described_class.new(form_data)
      form.expand_direct_deposit_information
      expect(form.instance_variable_get('@form_data')['bankAccount']['accountType']).to eq(1)

      form_data = { 'bankAccount' => nil }
      form = described_class.new(form_data)
      form.expand_direct_deposit_information
      expect(form.instance_variable_get('@form_data')['bankAccount']['accountType']).to eq(2)

      form_data = { 'bankAccount' => { 'accountType' => nil } }
      form = described_class.new(form_data)
      form.expand_direct_deposit_information
      expect(form.instance_variable_get('@form_data')['bankAccount']['accountType']).to be_nil
    end
  end

  describe '#expand_claim_certification_and_signature' do
    it 'defaults to today' do
      date = Time.new(2024, 11, 25, 2, 2, 2, 'UTC')
      zone = double('zone')
      allow(zone).to receive(:now).and_return(date)
      allow(Time).to receive(:zone).and_return(zone)
      form_data = {}
      form = described_class.new(form_data)
      form.expand_claim_certification_and_signature
      expect(form.instance_variable_get('@form_data')['signatureDate']).to eq({ 'month' => '11', 'day' => '25',
                                                                                'year' => '2024' })
    end

    it 'applies date if provided' do
      form_data = { 'signatureDate' => '2024-10-31' }
      form = described_class.new(form_data)
      form.expand_claim_certification_and_signature
      expect(form.instance_variable_get('@form_data')['signatureDate']).to eq({ 'month' => '10', 'day' => '31',
                                                                                'year' => '2024' })
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
