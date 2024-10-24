# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/installment_contracts_other_debts_calculator'

RSpec.describe DebtsApi::V0::FsrFormTransform::InstallmentContractsOtherDebtsCalculator, type: :service do
  describe '#initialize' do
    let(:pre_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform')
    end
    let(:post_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/post_transform')
    end

    let(:transformer_data) do
      transformer = described_class.new(pre_form_data)
      transformer.get_data
      transformer.get_totals_data
    end

    def get_data
      transformer = described_class.new(pre_form_data)
      @data = transformer.get_data
      @total_data = transformer.get_totals_data
    end

    describe '#get_data' do
      before do
        get_data
      end

      it 'gets installment contracts and other debts data correct' do
        expected_installment_contracts_other_debts_data = post_form_data['installmentContractsAndOtherDebts']
        expect(expected_installment_contracts_other_debts_data).to eq(@data)
      end

      it 'gets total of installment contracts and other debts data correct' do
        expected_installment_contracts_other_debts_data = post_form_data['totalOfInstallmentContractsAndOtherDebts']
        expect(expected_installment_contracts_other_debts_data).to eq(@total_data)
      end

      it 'returns empty string for creditorName' do
        pre_form_data['installment_contracts'].first['creditor_name'] = nil
        calculator = described_class.new(pre_form_data)
        calculator_data = calculator.get_data

        creditor_names = calculator_data.pluck('creditorName')
        expect(creditor_names).to eq(['', ''])
      end
    end
  end
end
