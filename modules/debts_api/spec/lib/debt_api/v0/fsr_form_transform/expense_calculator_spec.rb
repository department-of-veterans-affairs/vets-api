# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/expense_calculator'

RSpec.describe DebtsApi::V0::FsrFormTransform::ExpenseCalculator, type: :service do
  describe '#get_monthly_expenses' do
    before do
      allow(StatsD).to receive(:increment).and_call_original
    end

    let(:enhanced_expenses) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/enhanced_fsr_expenses')
    end
    let(:old_expenses) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/non_enhanced_fsr_expenses')
    end

    context 'with enhanced FSR' do
      it 'sums a bunch of stuff' do
        calculator = described_class.build(enhanced_expenses)
        expect(calculator.get_monthly_expenses).to eq(19_603.44)
      end
    end

    context 'with old FSR' do
      it 'throws an error' do
        expect do
          described_class.build(old_expenses)
        end.to raise_error(DebtsApi::V0::FsrFormTransform::UnprocessableFsrFormat)
      end
    end
  end

  describe '#getAllExpenses' do
    before do
      allow(StatsD).to receive(:increment).and_call_original
    end

    let(:enhanced_expenses) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/enhanced_fsr_expenses')
    end
    let(:old_expenses) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/non_enhanced_fsr_expenses')
    end

    context 'with enhanced FSR' do
      it 'gets rent/mortgage expenses from expenseRecords and tracks the expected metric' do
        calculator = described_class.build(enhanced_expenses)
        calculated_expenses = calculator.get_all_expenses
        expect(StatsD).to have_received(:increment)
          .once.with('api.fsr_submission.full_transform.expenses.old_rent_mortgage_attr')
        expect(calculated_expenses[:rentOrMortgage]).to eq(2200.53)
      end

      it 'tracks the expected metric for the new rent mortgage attribute when it is present' do
        enhanced_expenses['expenses']['monthlyHousingExpenses'] = ['fff']
        described_class.build(enhanced_expenses)
        expect(StatsD).to have_received(:increment)
          .once.with('api.fsr_submission.full_transform.expenses.new_rent_mortgage_attr')
      end

      it 'gets food expenses from expenseRecords' do
        calculator = described_class.build(enhanced_expenses)
        calculated_expenses = calculator.get_all_expenses
        expect(calculated_expenses[:food]).to eq('300.00')
      end

      it 'gets utilities from utilityRecords' do
        calculator = described_class.build(enhanced_expenses)
        calculated_expenses = calculator.get_all_expenses
        expect(calculated_expenses[:utilities]).to eq(701.35)
      end

      it 'gets living expenses from filtered expenses' do
        calculator = described_class.build(enhanced_expenses)
        calculated_expenses = calculator.get_all_expenses
        expect(calculated_expenses[:otherLivingExpenses][:name]).to eq('Pool service, Lawn service, something else')
        expect(calculated_expenses[:otherLivingExpenses][:amount]).to eq(400.54)
      end

      it 'gets expensesInstallmentContractsAndOtherDebts' do
        calculator = described_class.build(enhanced_expenses)
        calculated_expenses = calculator.get_all_expenses
        expect(calculated_expenses[:expensesInstallmentContractsAndOtherDebts]).to eq(12_000.64)
      end
    end

    context 'with old FSR' do
      it 'throws an error' do
        expect do
          described_class.build(old_expenses)
        end.to raise_error(DebtsApi::V0::FsrFormTransform::UnprocessableFsrFormat)
      end
    end
  end

  describe '#transform_expenses' do
    let(:pre_transform_fsr_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform')
    end
    let(:post_transform_fsr_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/post_transform')
    end

    it 'transforms expenses' do
      expected_expenses = post_transform_fsr_form_data['expenses']
      transformer = described_class.build(pre_transform_fsr_form_data)
      actual_expenses = transformer.transform_expenses
      expect(actual_expenses).to eq(expected_expenses)
    end
  end
end
