# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/income_calculator'
require 'debts_api/v0/fsr_form_transform/expense_calculator'
require 'debts_api/v0/fsr_form_transform/utils'

module DebtsApi
  module V0
    module FsrFormTransform
      class DiscretionaryIncomeCalculator
        include ::FsrFormTransform::Utils

        def initialize(form)
          @form = form
          income_calculator = DebtsApi::V0::FsrFormTransform::IncomeCalculator.new(form)
          @total_monthly_net_income = income_calculator.get_monthly_income[:totalMonthlyNetIncome]
          @expense_calculator = DebtsApi::V0::FsrFormTransform::ExpenseCalculator.build(form)
        end

        def get_data
          {
            'netMonthlyIncomeLessExpenses' => net_monthly_income_less_expenses,
            'amountCanBePaidTowardDebt' => amount_can_be_paid_toward_debt
          }
        end

        private

        def net_monthly_income_less_expenses
          format_number(@total_monthly_net_income - @expense_calculator.get_monthly_expenses)
        end

        def amount_can_be_paid_toward_debt
          debts_and_copays = @form['selected_debts_and_copays']
          amount_paid = debts_and_copays
                        .select { |item| item['resolution_comment'].present? }
                        .reduce(0) { |acc, item| acc + str_to_num(item['resolution_comment']) }

          format_number(amount_paid)
        end
      end
    end
  end
end
