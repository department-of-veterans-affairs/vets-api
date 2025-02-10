# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/utils'

module DebtsApi
  module V0
    module FsrFormTransform
      class Income
        include ::FsrFormTransform::Utils

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

        def initialize(income_params)
          @additional_income = income_params[:additional_income]
          @employment_records = income_params[:employment_records]
          @current_employment = income_params[:current_employment]
          @social_security = income_params[:social_security]
          @compensation_and_pension = income_params[:compensation_and_pension]
          @education = income_params[:education]
          @beneficiary_type = income_params[:beneficiary_type]
          @enhanced_fsr_active = income_params[:enhanced_fsr_active]
        end

        def income_statement
          {
            grossSalary: gross_salary,
            deductions: {
              taxes: tax_deductions,
              retirement: retirement_deductions,
              socialSecurity: social_security_deductions,
              otherDeductions: other_deductions
            },
            totalDeductions: total_deductions,
            netTakeHomePay: net_take_home_pay,
            otherIncome: other_income,
            totalMonthlyNetIncome: total_monthly_net_income
          }
        end

        def income_statement_as_json
          {
            'veteranOrSpouse' => BENEFICIARY_MAP[@beneficiary_type],
            'monthlyGrossSalary' => dollars_cents(gross_salary),
            'deductions' => {
              'taxes' => dollars_cents(tax_deductions),
              'retirement' => dollars_cents(retirement_deductions),
              'socialSecurity' => dollars_cents(social_security_deductions),
              'otherDeductions' => {
                'name' => other_deductions[:name],
                'amount' => dollars_cents(other_deductions[:amount].to_f)
              }
            },
            'totalDeductions' => dollars_cents(total_deductions),
            'netTakeHomePay' => dollars_cents(net_take_home_pay),
            'otherIncome' => {
              'name' => other_income[:name],
              'amount' => dollars_cents(other_income[:amount])
            },
            'totalMonthlyNetIncome' => dollars_cents(total_monthly_net_income)
          }
        end

        def total_monthly_net_income
          (gross_salary - total_deductions + other_income[:amount]).round(2)
        end

        private

        def gross_salary
          if @enhanced_fsr_active
            @employment_records.sum { |emp| emp['gross_monthly_income'].to_f }
          else
            @current_employment.sum { |emp| emp["#{beneficiary_type}_gross_salary"].to_f }
          end.to_f.round(2)
        end

        def deductions
          if @enhanced_fsr_active
            @employment_records
              .select { |emp| emp['is_current'] }
              .map { |emp| emp['deductions'] || 0 }
          else
            @current_employment.pluck('deductions')
          end.flatten
        end

        def tax_deductions
          filter_reduce_by_name(deductions, TAX_FILTERS)
        end

        def retirement_deductions
          filter_reduce_by_name(deductions, RETIREMENT_FILTERS)
        end

        def social_security_deductions
          filter_reduce_by_name(deductions, SOCIAL_SEC_FILTERS)
        end

        def other_deductions
          {
            name: other_deductions_name(deductions, ALL_FILTERS),
            amount: other_deductions_amt(deductions, ALL_FILTERS)
          }
        end

        def total_deductions
          [tax_deductions, retirement_deductions, social_security_deductions].sum + other_deductions[:amount]
        end

        def other_income
          addl_inc = @additional_income.sum { |i| i['amount'].to_f }.to_f.round(2)
          soc_sec_amt = @social_security.to_f.round(2)
          comp = @compensation_and_pension.to_f.round(2)
          edu =  @education.to_f.round(2)

          other_income_total = addl_inc + comp + edu + soc_sec_amt

          {
            name: name_str(soc_sec_amt, comp, edu, @additional_income),
            amount: other_income_total.round(2)
          }
        end

        def net_take_home_pay
          (gross_salary - total_deductions)
        end

        # formerly filter_reduce_by_name
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

        # formerly other_deductions_amt
        def other_deductions_amt(deductions, filters)
          return 0 if deductions.empty?

          deductions
            .reject { |deduction| deduction['name'].nil? || filters.include?(deduction['name']) }
            .sum { |deduction| deduction['amount']&.gsub(/[^0-9.-]/, '')&.to_f || 0 }
        end

        # formerly name_str
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
