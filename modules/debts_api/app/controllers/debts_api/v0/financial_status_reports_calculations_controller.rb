# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/asset_calculator'
require 'debts_api/v0/fsr_form_transform/expense_calculator'
require 'debts_api/v0/fsr_form_transform/income_calculator'

module DebtsApi
  module V0
    class FinancialStatusReportsCalculationsController < ApplicationController
      service_tag 'financial-report'

      def total_assets
        render json: {
          calculatedTotalAssets: asset_calculator.get_total_assets
        }
      end

      def monthly_income
        render json: income_calculator.combined_monthly_income_statement
      end

      def monthly_expenses
        render json: {
          calculatedMonthlyExpenses: expense_calculator.get_monthly_expenses
        }
      end

      def all_expenses
        render json: expense_calculator.get_all_expenses
      end

      private

      # rubocop:disable Metrics/MethodLength
      def asset_form
        params.permit(
          :cash_in_bank,
          :cash_on_hand,
          :rec_vehicle_amount,
          :us_savings_bonds,
          :stocks_and_other_bonds,
          :'view:enhanced_financial_status_report',
          questions: [:has_vehicle],
          real_estate_records: %i[
            real_estate_type
            real_estate_amount
          ],
          assets: [
            :resale_value,
            {
              other_assets: %i[
                name
                amount
              ]
            },
            { monetary_assets: %i[name amount] },
            :rec_vehicle_amount,
            :real_estate_value,
            { automobiles: [:resale_value] }
          ]
        )
      end

      def income_form
        params.permit(
          :'view:enhanced_financial_status_report',
          additional_income: [
            {
              addl_inc_records: %i[
                name
                amount
              ]
            },
            {
              spouse: [
                sp_addl_income: %i[
                  name
                  amount
                ]
              ]
            }
          ],
          benefits: {
            spouse_benefits: %i[
              compensation_and_pension
              education
            ]
          },
          curr_employment: [
            :veteran_gross_salary,
            {
              deductions: %i[
                name
                amount
              ]
            },
            :name,
            :amount,
            :type,
            :from,
            :to,
            :is_current,
            :employer_name
          ],
          income: %i[
            veteran_or_spouse
            compensation_and_pension
            education
          ],
          personal_data: {
            employment_history: {
              veteran: {
                employment_records: [
                  :type,
                  :from,
                  :to,
                  :is_current,
                  :employer_name,
                  :gross_monthly_income,
                  {
                    deductions: %i[name amount]
                  }
                ]
              },
              spouse: {
                sp_employment_records: [
                  :type,
                  :from,
                  :to,
                  :is_current,
                  :employer_name,
                  :gross_monthly_income,
                  {
                    deductions: %i[name amount]
                  }
                ]
              }
            }
          },
          sp_curr_employment: [
            :spouse_gross_salary,
            {
              deductions: %i[
                name
                amount
              ]
            },
            :name,
            :amount,
            :type,
            :from,
            :to,
            :is_current,
            :employer_name
          ],
          social_security: [
            :social_sec_amt,
            { spouse: [
              :social_sec_amt
            ] }
          ]
        ).to_hash
      end

      def expense_form
        params.permit(
          :'view:enhanced_financial_status_report',
          expenses: [
            :food,
            :rent_or_mortgage,
            { expense_records: %i[
                name
                amount
              ],
              credit_card_bills: %i[
                purpose
                creditor_name
                original_amount
                unpaid_balance
                amount_due_monthly
                date_started
                amount_past_due
              ] }
          ],
          other_expenses: %i[
            name
            amount
          ],
          installment_contracts: %i[
            creditor_name
            date_started
            purpose
            original_amount
            unpaid_balance
            amount_due_monthly
            amount_past_due
          ],
          utility_records: %i[
            utility_type
            amount
            monthly_utility_amount
          ]
        ).to_hash
      end
      # rubocop:enable Metrics/MethodLength

      def asset_calculator
        DebtsApi::V0::FsrFormTransform::AssetCalculator.new(asset_form)
      end

      def income_calculator
        DebtsApi::V0::FsrFormTransform::IncomeCalculator.new(income_form)
      end

      def expense_calculator
        DebtsApi::V0::FsrFormTransform::ExpenseCalculator.build(expense_form)
      end
    end
  end
end
