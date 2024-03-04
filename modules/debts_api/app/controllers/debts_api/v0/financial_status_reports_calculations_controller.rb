# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/asset_calculator'
require 'debts_api/v0/fsr_form_transform/expense_calculator'
require 'debts_api/v0/fsr_form_transform/income_calculator'

module DebtsApi
  module V0
    class FinancialStatusReportsCalculationsController < ApplicationController
      service_tag 'financial-report'

      def total_assets
        render json: asset_calculator.get_total_assets
      end

      def monthly_income
        render json: income_calculator.get_monthly_income
      end

      def monthly_expenses
        render json: expense_calculator.get_monthly_expenses
      end

      def all_expenses
        render json: expense_calculator.get_all_expenses
      end

      private

      # rubocop:disable Metrics/MethodLength
      def asset_form
        params.require(:data).permit(
          :cashInBank,
          :cashOnHand,
          :recVehicleAmount,
          :usSavingsBonds,
          :stocksAndOtherBonds,
          :'view:enhancedFinancialStatusReport',
          questions: [:hasVehicle],
          realEstateRecords: %i[
            realEstateType
            realEstateAmount
          ],
          assets: [
            :realEstateValue,
            {
              otherAssets: %i[
                name
                amount
              ]
            },
            :recVehicleAmount,
            { automobiles: [:resaleValue] }
          ]
        )
      end

      def income_form
        params.require(:data).permit(
          :'view:enhancedFinancialStatusReport',
          additionalIncome: [
            {
              addlIncRecords: %i[
                name
                amount
              ]
            },
            {
              spouse: %i[
                spAddlIncome
              ]
            }
          ],
          benefits: {
            spouseBenefits: %i[
              compensationAndPension
              education
            ]
          },
          currEmployment: [
            :veteranGrossSalary,
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
            :isCurrent,
            :employerName
          ],
          income: %i[
            veteranOrSpouse
            compensationAndPension
            education
          ],
          personalData: {
            employmentHistory: {
              veteran: {
                employmentRecords: [
                  :type,
                  :from,
                  :to,
                  :isCurrent,
                  :employerName,
                  :grossMonthlyIncome,
                  {
                    deductions: %i[name amount]
                  }
                ]
              },
              spouse: {
                spEmploymentRecords: [
                  :type,
                  :from,
                  :to,
                  :isCurrent,
                  :employerName,
                  :grossMonthlyIncome,
                  {
                    deductions: %i[name amount]
                  }
                ]
              }
            }
          },
          spCurrEmployment: [
            :spouseGrossSalary,
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
            :isCurrent,
            :employerName
          ],
          socialSecurity: [
            :socialSecAmt,
            { spouse: [
              :socialSecAmt
            ] }
          ]
        ).to_hash
      end

      def expense_form
        params.permit(
          :'view:enhancedFinancialStatusReport',
          expenses: [
            :food,
            :rentOrMortgage,
            { expenseRecords: %i[
                name
                amount
              ],
              creditCardBills: %i[
                purpose
                creditorName
                originalAmount
                unpaidBalance
                amountDueMonthly
                dateStarted
                amountPastDue
              ] }
          ],
          otherExpenses: %i[
            name
            amount
          ],
          installmentContracts: %i[
            creditorName
            dateStarted
            purpose
            originalAmount
            unpaid_balance
            amountDueMonthly
            amountPastDue
          ],
          utilityRecords: %i[
            utilityType
            amount
            monthlyUtilityAmount
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
        DebtsApi::V0::FsrFormTransform::ExpenceCalculator.build(expense_form)
      end
    end
  end
end
