# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/income'

module DebtsApi
  module V0
    module FsrFormTransform
      class IncomeCalculator
        # Refactoring Steps
        # 1. Remove duplicate instance variables related to `get_monthly_income`
        # 2. Replace `calculate_income` parameters with respective instance variables
        # 3. Refactor `transformed_income` to be stringify calculate_income output
        # 4. Extract private methods from calculate_income
        # 5. Move calculate_income hash to (vet|spouse)_income

        def initialize(form)
          @form = form
          @additional_income = @form['additional_income']
          @employment_history = @form.dig('personal_data', 'employment_history')
          @social_security = @form['social_security'] || {}
          @benefits = @form['benefits'] || {}
          @income = @form['income'] || []
          @enhanced_fsr_active = @form['view:enhanced_financial_status_report']
        end

        # formerly get_monthly_income
        def combined_monthly_income_statement
          {
            vetIncome: vet_income.income_statement,
            spIncome: sp_income.income_statement,
            totalMonthlyNetIncome: total_monthly_net_income
          }
        end

        # formerly get_transformed_income
        def monthly_income_statements_as_json
          [vet_income.income_statement_as_json, sp_income.income_statement_as_json]
        end

        def total_monthly_net_income
          sp_sum = sp_income.income_statement.empty? ? 0 : sp_income.total_monthly_net_income
          vet_income.total_monthly_net_income + sp_sum
        end

        def total_annual_net_income
          total_monthly_net_income.to_f * 12
        end

        private

        def vet_income
          @vet_income ||= Income.new(veteran_income_params)
        end

        def sp_income
          @sp_income ||= Income.new(spouse_income_params)
        end

        def veteran_income_params
          {
            additional_income: @additional_income.fetch('addl_inc_records', []),
            employment_records: @employment_history.dig('veteran', 'employment_records') || [],
            curr_employment: @form['curr_employment'] || [],
            social_security: @social_security['social_sec_amt'].to_f || 0,
            compensation_and_pension: @income.sum { |item| item['compensation_and_pension'].to_f },
            education: @income.sum { |item| item['education'].to_f },
            beneficiary_type: 'veteran',
            enhanced_fsr_active: @enhanced_fsr_active
          }
        end

        def spouse_income_params
          {
            additional_income: @additional_income.dig('spouse', 'sp_addl_income') || [],
            employment_records: @employment_history.dig('spouse', 'sp_employment_records') || [],
            curr_employment: @form['sp_curr_employment'] || [],
            social_security: @social_security.dig('spouse', 'social_sec_amt').to_f || 0,
            compensation_and_pension: @benefits.dig('spouse_benefits', 'compensation_and_pension').to_f || 0,
            education: @benefits.dig('spouse_benefits', 'education').to_f || 0,
            beneficiary_type: 'spouse',
            enhanced_fsr_active: @enhanced_fsr_active
          }
        end
      end
    end
  end
end
