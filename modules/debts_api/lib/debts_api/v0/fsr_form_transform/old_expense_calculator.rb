# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/expense_calculator'
require 'debts_api/v0/fsr_form_transform/utils'

module DebtsApi
  module V0
    module FsrFormTransform
      class OldExpenseCalculator
        include ::FsrFormTransform::Utils

        RENT = 'Rent'
        MORTGAGE_PAYMENT = 'Mortgage payment'
        FOOD = 'Food'

        def initialize(form)
          @form = form
          @enhanced = form['view:enhancedFinancialStatusReport'] || false
          @expense_records = @form.dig('expenses', 'expenseRecords') || []
          @old_rent_mortgage_attr = @form.dig('expenses', 'rentOrMortgage')
          @old_food_attr = @form.dig('expenses', 'food')
          @credit_card_bills = @form.dig('expenses', 'creditCardBills') || []
          @other_expenses = @form['otherExpenses'].deep_dup || []
          @installment_contracts = @form['installmentContracts']
          @utility_records = @form['utilityRecords']

          @filtered_expenses = [].concat(
            exclude_expenses_by(@other_expenses, [FOOD]),
            exclude_expenses_by(@expense_records, [RENT, MORTGAGE_PAYMENT])
          )
          @all_expenses ||= get_all_expenses
        end

        def get_monthly_expenses
          utilities = get_utilities
          installments = safe_sum(@installment_contracts.pluck('amountDueMonthly'))
          other_exp = safe_sum(@other_expenses.pluck('amount'))
          calculated_exp_records = safe_sum(@expense_records.pluck('amount'))
          food = safe_number(@old_food_attr)
          rent_or_mortgage_sum = safe_number(@old_rent_mortgage_attr)
          credit_card_bills = safe_sum(@credit_card_bills.pluck('amountDueMonthly'))

          sum = utilities +
                installments +
                other_exp +
                calculated_exp_records +
                food +
                rent_or_mortgage_sum +
                credit_card_bills

          sum.round(2)
        end

        def get_all_expenses
          {
            rentOrMortgage: get_rent_mortgage_expenses,
            food: get_food_expenses,
            utilities: get_utilities,
            otherLivingExpenses: get_other_living_expenses,
            expensesInstallmentContractsAndOtherDebts: get_installments_and_other_debts,
            otherExpenses: @other_expenses,
            filteredExpenses: @filtered_expenses,
            installmentContractsAndCreditCards: [@installment_contracts, @credit_card_bills].flatten
          }
        end

        private

        def get_rent_mortgage_expenses
          safe_number(@old_rent_mortgage_attr)
        end

        def get_food_expenses
          safe_number(@old_food_attr)
        end

        def get_utilities
          amounts = @utility_records.pluck('monthlyUtilityAmount')
          safe_sum(amounts)
        end

        def get_other_living_expenses
          {
            name: @other_expenses.pluck('name').join(', '),
            amount: safe_sum(@other_expenses.pluck('amount'))
          }
        end

        def get_installments_and_other_debts
          installment_monthly_due = @installment_contracts.pluck('amountDueMonthly')
          credit_card_monthly_due = @credit_card_bills.pluck('amountDueMonthly')
          safe_sum([installment_monthly_due, credit_card_monthly_due].flatten)
        end
      end
    end
  end
end
