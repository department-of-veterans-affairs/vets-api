# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/personal_data_calculator'

RSpec.describe DebtsApi::V0::FsrFormTransform::PersonalDataCalculator, type: :service do
  describe '#initialize' do
    let(:pre_transform_fsr_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform')
    end
    let(:post_transform_fsr_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/post_transform')
    end
    let(:transformer_data) do
      transformer = described_class.new(pre_transform_fsr_form_data)
      transformer.get_personal_data
    end

    describe '#get_personal_data' do
      it 'gets personal data correct' do
        expected_personal_data = post_transform_fsr_form_data['personalData']
        expect(expected_personal_data).to eq(transformer_data)
      end

      it 'returns empty string for spouseFullName/last' do
        pre_transform_fsr_form_data['personal_data']['spouse_full_name']['last'] = nil
        calculator = described_class.new(pre_transform_fsr_form_data)
        calculator_data = calculator.get_personal_data

        expect(calculator_data['spouseFullName']['last']).to eq('')
      end

      it 'returns empty string for addressLine2 and addressLine3' do
        pre_transform_fsr_form_data['personal_data']['veteran_contact_information']['address']['address_line2'] = nil
        calculator = described_class.new(pre_transform_fsr_form_data)
        calculator_data = calculator.get_personal_data

        expect(calculator_data['address']['addresslineTwo']).to eq('')
        expect(calculator_data['address']['addresslineThree']).to eq('')
      end
    end
  end
end
