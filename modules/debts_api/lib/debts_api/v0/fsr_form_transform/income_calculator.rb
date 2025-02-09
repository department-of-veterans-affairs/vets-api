# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/utils'

module DebtsApi
  module V0
    module FsrFormTransform
      class IncomeCalculator
        include ::FsrFormTransform::Utils

        # Refactoring Steps
        # 1. Remove duplicate instance variables related to `get_monthly_income`
        # 2. Replace `calculate_income` parameters with respective instance variables
        # 3. Refactor `transformed_income` to be stringify calculate_income output
        # 4. Extract private methods from calculate_income
        # 5. Move calculate_income hash to (vet|spouse)_income

        BENEFICIARY_MAP = {
          'veteran' => 'VETERAN',
          'spouse' => 'SPOUSE'
        }.freeze
        TAX_FILTERS = ['State tax', 'Federal tax', 'Local tax'].freeze
        RETIREMENT_FILTERS = [
          'Retirement accounts (401k, IRAs, 403b, TSP)',
          '401K',
          'IRA',
          'Pension'
        ].freeze
        SOCIAL_SEC_FILTERS = ['FICA (Social Security and Medicare)'].freeze
        ALL_FILTERS = TAX_FILTERS + RETIREMENT_FILTERS + SOCIAL_SEC_FILTERS

        def initialize(form)
          @form = form
          @sp_addl_income = @form.dig('additional_income', 'spouse', 'sp_addl_income') || []
          @addl_inc_records = @form.dig('additional_income', 'addl_inc_records') || []
          @vet_employment_records = @form.dig('personal_data', 'employment_history', 'veteran',
                                              'employment_records') || []
          @sp_employment_records = @form.dig('personal_data', 'employment_history', 'spouse',
                                             'sp_employment_records') || []
          @social_security = @form['social_security'] || {}
          @benefits = @form['benefits'] || {}
          @curr_employment = @form['curr_employment'] || []
          @sp_curr_employment = @form['sp_curr_employment'] || []
          @income = @form['income'] || []
          @enhanced_fsr_active = @form['view:enhanced_financial_status_report']
        end

        def get_monthly_income
          sp_sum = sp_income.empty? ? 0 : sp_income[:totalMonthlyNetIncome]
          total_monthly_net_income = vet_income[:totalMonthlyNetIncome] + sp_sum

          {
            vetIncome: vet_income,
            spIncome: sp_income,
            totalMonthlyNetIncome: total_monthly_net_income
          }
        end

        def vet_income
          @vet_income ||= {
            grossSalary: veteran_gross_salary,
            deductions: veteran_deductions,
            totalDeductions: veteran_total_deductions,
            netTakeHomePay: (veteran_gross_salary - veteran_total_deductions),
            otherIncome: veteran_other_income,
            totalMonthlyNetIncome: (veteran_gross_salary - veteran_total_deductions + veteran_other_income[:amount]).round(2)
          }
        end

        def sp_income
          @sp_income ||= {
            grossSalary: spouse_gross_salary,
            deductions: spouse_deductions,
            totalDeductions: spouse_total_deductions,
            netTakeHomePay: (spouse_gross_salary - spouse_total_deductions),
            otherIncome: spouse_other_income,
            totalMonthlyNetIncome: (spouse_gross_salary - spouse_total_deductions + spouse_other_income[:amount]).round(2)
          }
        end

        def get_transformed_income
          [transformed_vet_income, transformed_sp_income]
        end

        def transformed_vet_income
          transform_income('veteran', vet_income)
        end

        def transformed_sp_income
          transform_income('spouse', sp_income)
        end

        private

        def transform_income(beneficiary_type, income)
          {
            'veteranOrSpouse' => BENEFICIARY_MAP[beneficiary_type],
            'monthlyGrossSalary' => dollars_cents(income[:grossSalary]),
            'deductions' => {
              'taxes' => dollars_cents(income[:deductions][:taxes]),
              'retirement' => dollars_cents(income[:deductions][:retirement]),
              'socialSecurity' => dollars_cents(income[:deductions][:socialSecurity]),
              'otherDeductions' => {
                'name' => income[:deductions][:otherDeductions][:name],
                'amount' => dollars_cents(income[:deductions][:otherDeductions][:amount].to_f)
              }
            },
            'totalDeductions' => dollars_cents(income[:totalDeductions]),
            'netTakeHomePay' => dollars_cents(income[:netTakeHomePay]),
            'otherIncome' => {
              'name' => income[:otherIncome][:name],
              'amount' => dollars_cents(income[:otherIncome][:amount])
            },
            'totalMonthlyNetIncome' => dollars_cents(income[:totalMonthlyNetIncome])
          }
        end

        def veteran_gross_salary
          gross_salary = if @enhanced_fsr_active
            @vet_employment_records.map do |emp|
              if emp['gross_monthly_income'].nil?
                0
              else
                emp['gross_monthly_income'].to_f
              end
            end.sum
          else
            @curr_employment.sum do |emp|
              emp["#{beneficiary_type}_gross_salary"].to_f
            end
          end
          gross_salary.to_f.round(2)
        end

        def spouse_gross_salary
          gross_salary = if @enhanced_fsr_active
            @sp_employment_records.map do |emp|
              if emp['gross_monthly_income'].nil?
                0
              else
                emp['gross_monthly_income'].to_f
              end
            end.sum
          else
            @sp_curr_employment.sum do |emp|
              emp["#{beneficiary_type}_gross_salary"].to_f
            end
          end
          gross_salary.to_f.round(2)
        end

        def veteran_deductions
          deductions = if @enhanced_fsr_active
            @vet_employment_records
              .select { |emp| emp['is_current'] }
              .map do |emp|
              if emp['deductions'].nil?
                0
              else
                emp['deductions']
              end
            end
            .flatten
          else
            @curr_employment.pluck('deductions').flatten
          end

          deduction_details(deductions)
        end

        def spouse_deductions
          deductions = if @enhanced_fsr_active
            @sp_employment_records
              .select { |emp| emp['is_current'] }
              .map do |emp|
              if emp['deductions'].nil?
                0
              else
                emp['deductions']
              end
            end
            .flatten
          else
            @sp_curr_employment.pluck('deductions').flatten
          end

          deduction_details(deductions)
        end

        def deduction_details(deductions)
          {
            taxes: filter_reduce_by_name(deductions, TAX_FILTERS),
            retirement: filter_reduce_by_name(deductions, RETIREMENT_FILTERS),
            socialSecurity: filter_reduce_by_name(deductions, SOCIAL_SEC_FILTERS),
            otherDeductions: {
              name: other_deductions_name(deductions, ALL_FILTERS),
              amount: other_deductions_amt(deductions, ALL_FILTERS)
            }
          }
        end

        def veteran_total_deductions
          # taxes + retirement + socialSecurity + other deductions
          veteran_deductions.except(:otherDeductions).values.sum + veteran_deductions[:otherDeductions][:amount]
        end

        def spouse_total_deductions
          # taxes + retirement + socialSecurity + other deductions
          spouse_deductions.except(:otherDeductions).values.sum + spouse_deductions[:otherDeductions][:amount]
        end

        def veteran_other_income
          addl_inc = @addl_inc_records.sum { |record| record['amount'].to_f }
          soc_sec_amt = @enhanced_fsr_active ? 0 : @social_security['social_sec_amt'].to_f || 0
          comp = @income.sum { |item| item['compensation_and_pension'].to_f }
          edu =  @income.sum { |item| item['education'].to_f }

          other_income_total = addl_inc.to_f.round(2) + comp.to_f.round(2) + edu.to_f.round(2) + soc_sec_amt.to_f.round(2)

          {
            name: name_str(soc_sec_amt, comp, edu, @addl_inc_records),
            amount: other_income_total.round(2)
          }
        end

        def spouse_other_income
          addl_inc = @sp_addl_income.sum { |record| record['amount'].to_f }
          soc_sec_amt = @enhanced_fsr_active ? 0 : @social_security.dig('spouse', 'social_sec_amt').to_f || 0
          comp = @benefits.dig('spouse_benefits', 'compensation_and_pension').to_f || 0
          edu = @benefits.dig('spouse_benefits', 'education').to_f || 0

          other_income_total = addl_inc.to_f.round(2) + comp.to_f.round(2) + edu.to_f.round(2) + soc_sec_amt.to_f.round(2)

          {
            name: name_str(soc_sec_amt, comp, edu, @sp_addl_income),
            amount: other_income_total.round(2)
          }
        end

        def filter_reduce_by_name(deductions, filters)
          return 0.0 unless deductions&.any?

          deductions
            .select { |deduction| filters.include?(deduction['name']) }
            .reduce(0.0) do |acc, curr|
              acc + curr['amount']&.gsub(/[^0-9.-]/, '').to_f
            end
        end

        def other_deductions_name(deductions, filters)
          return '' if deductions.empty?

          deductions.reject { |deduction| filters.include?(deduction['name']) }
                    .pluck('name')
                    .join(', ')
        end

        def other_deductions_amt(deductions, filters)
          return 0 if deductions.empty?

          deductions
            .reject { |deduction| deduction['name'].nil? || filters.include?(deduction['name']) }
            .sum { |deduction| deduction['amount']&.gsub(/[^0-9.-]/, '')&.to_f || 0 }
        end

        def name_str(social_security, compensation, education, addl_inc)
          benefit_types = []
          benefit_types.push('Social Security') if social_security.positive?
          benefit_types.push('Disability Compensation') if compensation.positive?
          benefit_types.push('Education') if education.positive?

          vet_addl_names = addl_inc&.pluck('name') || []
          other_inc_names = [*benefit_types, *vet_addl_names]

          other_inc_names&.join(', ') || ''
        end
      end
    end
  end
end
