# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/expense_calculator'
require 'debts_api/v0/fsr_form_transform/utils'

module DebtsApi
  module V0
    module FsrFormTransform
      class EnhancedExpenseCalculator
        include ::FsrFormTransform::Utils

        RENT = 'Rent'
        MORTGAGE_PAYMENT = 'Mortgage payment'
        FOOD = 'Food'
        attr_reader :filtered_expenses

        def initialize(form)
          @form = form
          @enhanced = form['view:enhancedFinancialStatusReport'] || false
          @expense_page_active = @form['view:showUpdatedExpensePages'] || false
          @expense_records = @form.dig('expenses', 'expenseRecords') || []
          @old_rent_mortgage_attr = @form.dig('expenses', 'rentOrMortgage') || 0
          @new_rent_mortgage_attr = @form.dig('expenses', 'monthlyHousingExpenses')
          @old_food_attr = @form.dig('expenses', 'food')
          @credit_card_bills = @form.dig('expenses', 'creditCardBills') || []
          @other_expenses = @form['otherExpenses'].deep_dup || []
          @installment_contracts = @form['installmentContracts'] || []
          @utility_records = @form['utilityRecords'] || []

          @filtered_expenses = [].concat(
            exclude_expenses_by(@other_expenses, [FOOD]),
            exclude_expenses_by(@expense_records, [RENT, MORTGAGE_PAYMENT])
          )

          update_rent_mortgage_tracking_metrics

          @all_expenses ||= get_all_expenses
        end

        def get_monthly_expenses
          utilities = get_utilities
          installments = safe_sum(@installment_contracts.pluck('amountDueMonthly'))
          other_exp = safe_sum(@other_expenses.pluck('amount'))
          calculated_exp_records = safe_sum(@expense_records.pluck('amount'))
          food = safe_number(@old_food_attr)
          rent_or_mortgage_sum = get_rent_mortgage_expenses
          credit_card_bills = safe_sum(@credit_card_bills.pluck('amountDueMonthly'))

          sum = utilities +
                installments +
                other_exp +
                calculated_exp_records +
                food +
                rent_or_mortgage_sum +
                credit_card_bills
          sum -= rent_or_mortgage_sum unless @expense_page_active # rent/mortgage included in calculated_exp_records

          sum.round(2)
        end

        def get_all_expenses
          {
            rentOrMortgage: get_rent_mortgage_expenses,
            food: dollars_cents(get_food_expenses),
            utilities: get_utilities,
            otherLivingExpenses: get_other_living_expenses,
            expensesInstallmentContractsAndOtherDebts: get_installments_and_other_debts,
            otherExpenses: @other_expenses,
            filteredExpenses: @filtered_expenses,
            installmentContractsAndCreditCards: [@installment_contracts, @credit_card_bills].flatten
          }
        end

        def transform_expenses
          expenses = default_expenses
          expenses['rentOrMortgage'] = dollars_cents(get_rent_mortgage_expenses.to_f)
          expenses['food'] = dollars_cents(get_food_expenses)
          expenses['utilities'] = dollars_cents(get_utilities.to_f)
          other = get_other_living_expenses
          expenses['otherLivingExpenses'] = {
            'name' => other[:name],
            'amount' => dollars_cents(other[:amount].to_f)
          }
          expenses['expensesInstallmentContractsAndOtherDebts'] = dollars_cents(get_installments_and_other_debts.to_f)
          expenses['totalMonthlyExpenses'] = dollars_cents(get_monthly_expenses)
          expenses
        end

        private

        def default_expenses
          {
            'rentOrMortgage' => '0.00',
            'food' => '0.00',
            'utilities' => '0.00',
            'otherLivingExpenses' => {},
            'expensesInstallmentContractsAndOtherDebts' => '0.00',
            'totalMonthlyExpenses' => '0.00'
          }
        end

        def get_rent_mortgage_expenses
          return safe_number(@new_rent_mortgage_attr) if @expense_page_active

          rent_or_mortgage_expenses = @expense_records.filter do |record|
            [RENT, MORTGAGE_PAYMENT].include?(record['name'])
          end
          safe_sum(rent_or_mortgage_expenses.pluck('amount')) + @old_rent_mortgage_attr
        end

        def get_food_expenses
          food_expenses = @other_expenses.find { |expense| expense['name'] == 'Food' } || { amount: 0 }
          safe_number(food_expenses['amount'])
        end

        def get_utilities
          amounts = @utility_records.pluck('amount')
          safe_sum(amounts)
        end

        def get_other_living_expenses
          {
            name: @filtered_expenses.pluck('name').join(', '),
            amount: safe_sum(@filtered_expenses.pluck('amount'))
          }
        end

        def get_installments_and_other_debts
          installment_monthly_due = @installment_contracts.pluck('amountDueMonthly')
          credit_card_monthly_due = @credit_card_bills.pluck('amountDueMonthly')
          safe_sum([installment_monthly_due, credit_card_monthly_due].flatten)
        end

        def update_rent_mortgage_tracking_metrics
          return unless @new_rent_mortgage_attr.present? || @old_rent_mortgage_attr.present?

          tracking_label = "#{@new_rent_mortgage_attr.present? ? 'new' : 'old'}_rent_mortgage_attr"
          StatsD.increment("#{DebtsApi::V0::Form5655Submission::STATS_KEY}.full_transform.expenses.#{tracking_label}")
        end
      end
    end
  end
end
