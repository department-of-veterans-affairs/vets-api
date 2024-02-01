# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/income_calculator'

module DebtsApi
  module V0
    class FinancialStatusReportsCalculationsController < ApplicationController
      service_tag 'financial-report'

      def monthly_income
        render json: income_calculator.get_monthly_income
      end

      private

      # rubocop:disable Metrics/MethodLength
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
      # rubocop:enable Metrics/MethodLength

      def income_calculator
        DebtsApi::V0::FsrFormTransform::IncomeCalculator.new(income_form)
      end
    end
  end
end
