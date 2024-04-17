# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/expense_calculator'

RSpec.describe DebtsApi::V0::FsrFormTransform::ExpenseCalculator, type: :service do
  describe '#get_monthly_expenses' do
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
      it 'sums a bunch of stuff' do
        calculator = described_class.build(old_expenses)
        expect(calculator.get_monthly_expenses).to eq(18_464.79)
      end
    end
  end

  describe '#getAllExpenses' do
    let(:enhanced_expenses) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/enhanced_fsr_expenses')
    end
    let(:old_expenses) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/non_enhanced_fsr_expenses')
    end

    context 'with enhanced FSR' do
      it 'gets rent/mortgage expenses from expenseRecords' do
        calculator = described_class.build(enhanced_expenses)
        calculated_expenses = calculator.get_all_expenses
        expect(calculated_expenses[:rentOrMortgage]).to eq(2200.53)
      end

      it 'gets food expenses from expenseRecords' do
        calculator = described_class.build(enhanced_expenses)
        calculated_expenses = calculator.get_all_expenses
        expect(calculated_expenses[:food]).to eq(300)
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
      it 'gets rent/mortgage expenses from rentOrMortgage field' do
        calculator = described_class.build(old_expenses)
        calculated_expenses = calculator.get_all_expenses
        expect(calculated_expenses[:rentOrMortgage]).to eq(1200.25)
      end

      it 'gets food expenses from expenseRecords' do
        calculator = described_class.build(old_expenses)
        calculated_expenses = calculator.get_all_expenses
        expect(calculated_expenses[:food]).to eq(4000.38)
      end

      it 'gets utilities from utilityRecords' do
        calculator = described_class.build(old_expenses)
        calculated_expenses = calculator.get_all_expenses
        expect(calculated_expenses[:utilities]).to eq(662.98)
      end

      it 'gets living expenses from other expenses' do
        calculator = described_class.build(old_expenses)
        calculated_expenses = calculator.get_all_expenses
        expect(calculated_expenses[:otherLivingExpenses][:name]).to eq('Pool service, Lawn service, Food')
        expect(calculated_expenses[:otherLivingExpenses][:amount]).to eq(600.54)
      end

      it 'gets expensesInstallmentContractsAndOtherDebts' do
        calculator = described_class.build(old_expenses)
        calculated_expenses = calculator.get_all_expenses
        expect(calculated_expenses[:expensesInstallmentContractsAndOtherDebts]).to eq(12_000.64)
      end
    end
  end
end
