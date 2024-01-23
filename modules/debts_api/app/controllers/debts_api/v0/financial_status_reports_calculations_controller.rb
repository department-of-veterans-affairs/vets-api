# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/income_calculator'
require 'debts_api/v0/fsr_form_transform/expense_calculator'

module DebtsApi
  module V0
    class FinancialStatusReportsCalculationsController < ApplicationController
      
      def calculate_monthly_income(calculator, form_data)
        calculator.get_monthly_income(form_data)
      end

      def monthly_expenses
        render json: expense_calculator.get_monthly_expenses
      end

      def all_expenses
        render json: expense_calculator.get_all_expenses
      end

      private

      # rubocop:disable Metrics/MethodLength
      def expense_form
        params.permit(
          :"view:enhancedFinancialStatusReport",
          expenses: [
            :food,
            :rentOrMortgage,
            expenseRecords: [
              :name,
              :amount
            ],
            creditCardBills: [
              :purpose,
              :creditorName,
              :originalAmount,
              :unpaidBalance,
              :amountDueMonthly,
              :dateStarted,
              :amountPastDue
            ]
          ],
          otherExpenses: [
            :name,
            :amount
          ],
          installmentContracts: [
            :creditorName,
            :dateStarted,
            :purpose,
            :originalAmount,
            :unpaid_balance,
            :amountDueMonthly,
            :amountPastDue
          ],
          utilityRecords: [
            :utilityType,
            :amount,
            :monthlyUtilityAmount
          ]

        ).to_hash
      end
      # rubocop:enable Metrics/MethodLength

      def expense_calculator
        DebtsApi::V0::FsrFormTransform::ExpenceCalculator.build(expense_form)
      end
    end
  end
end
