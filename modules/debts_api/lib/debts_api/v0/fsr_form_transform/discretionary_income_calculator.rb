# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/income_calculator'
require 'debts_api/v0/fsr_form_transform/expense_calculator'

module DebtsApi
  module V0
    module FsrFormTransform
      class DiscretionaryIncomeCalculator
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
          debts_and_copays = @form['selectedDebtsAndCopays']
          amount_paid = debts_and_copays
                        .select { |item| item['resolutionComment'].present? }
                        .reduce(0) { |acc, item| acc + str_to_num(item['resolutionComment']) }

          format_number(amount_paid)
        end

        def str_to_num(str)
          return 0 unless str.instance_of?(String)

          str.gsub(/[^0-9.-]/, '').to_i || 0
        end

        def format_number(number)
          format('%.2f', number).to_s
        end
      end
    end
  end
end
