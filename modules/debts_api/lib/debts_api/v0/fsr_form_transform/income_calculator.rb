# frozen_string_literal: true

module DebtsApi
  module V0
    module FsrFormTransform
      class IncomeCalculator
        def initialize
          # Filters for deductions
          @tax_filters = ['State tax', 'Federal tax', 'Local tax']
          @retirement_filters = [
              'Retirement accounts (401k, IRAs, 403b, TSP)',
              '401K',
              'IRA',
              'Pension'
          ]
          @social_sec_filters = ['FICA (Social Security and Medicare)']
          @all_filters = @tax_filters + @retirement_filters + @social_sec_filters
        end

        def get_monthly_income(form_data)
          if form_data["additionalIncome"]["spouse"]["spAddlIncome"].blank?
            form_data["additionalIncome"]["spouse"]["spAddlIncome"] = []
          end
          if form_data["additionalIncome"]["addlIncRecords"].blank?
            form_data["additionalIncome"]["addlIncRecords"] = []
          end
          if form_data["personalData"]["employmentHistory"]["veteran"]["employmentRecords"].blank?
            form_data["personalData"]["employmentHistory"]["veteran"]["employmentRecords"] = []
          end
          if form_data["personalData"]["employmentHistory"]["spouse"]["spEmploymentRecords"].blank?
            form_data["personalData"]["employmentHistory"]["spouse"]["spEmploymentRecords"] = []
          end

          sp_addl_income = form_data["additionalIncome"]["spouse"]["spAddlIncome"]
          addl_inc_records = form_data["additionalIncome"]["addlIncRecords"]
          vet_employment_records = form_data["personalData"]["employmentHistory"]["veteran"]["employmentRecords"]
          sp_employment_records = form_data["personalData"]["employmentHistory"]["spouse"]["spEmploymentRecords"]
          social_security = form_data["socialSecurity"]
          benefits = form_data["benefits"]
          curr_employment = form_data["currEmployment"] || []
          sp_curr_employment = form_data["spCurrEmployment"] || []
          income = form_data["income"]
          enhanced_fsr_active = form_data['view:enhancedFinancialStatusReport']
          vet_income = calculate_income(
              enhanced_fsr_active,
              'veteran',
              vet_employment_records,
              curr_employment,
              addl_inc_records,
              social_security,
              income,
              benefits
          )
          sp_income = calculate_income(
              enhanced_fsr_active,
              'spouse',
              sp_employment_records,
              sp_curr_employment,
              sp_addl_income,
              social_security,
              income,
              benefits
          )
          
          sp_sum = sp_income.empty? ? 0 : sp_income[:totalMonthlyNetIncome]
          total_monthly_net_income = vet_income[:totalMonthlyNetIncome] + sp_sum

          {
              vetIncome: vet_income,
              spIncome: sp_income,
              totalMonthlyNetIncome: total_monthly_net_income
          }
        end

        private

        def filter_reduce_by_name(deductions, filters)
          return 0 unless deductions&.any?

          deductions
            .select { |deduction| filters.include?(deduction['name']) }
            .reduce(0) do |acc, curr|
              acc + (curr['amount']&.gsub(/[^0-9.-]/, '')&.to_f || 0)
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

          benefit_types.push('Social Security') if social_security
          benefit_types.push('Disability Compensation') if compensation
          benefit_types.push('Education') if education

          vet_addl_names = addl_inc&.map { |item| item['name'] } || []
          other_inc_names = [*benefit_types, *vet_addl_names]

          other_inc_names&.join(', ') || ''
        end

        def calculate_income(enhanced_fsr_active, beneficiary_type, employment_records = [], curr_employment = [],
                            addl_inc_records = [], social_security = {}, income = [], benefits = {})
          gross_salary = if enhanced_fsr_active
              employment_records.map {|emp|
                if emp['grossMonthlyIncome'].nil?
                  0
                else
                  emp['grossMonthlyIncome'].to_f
                end
              }.sum
            else
            curr_employment.sum { |emp| 
              emp["#{beneficiary_type}GrossSalary"].to_f }
          end
          
          addl_inc = addl_inc_records.sum { |record| record['amount'].to_f }

          soc_sec_amt = if enhanced_fsr_active
                          0
                          elsif beneficiary_type == 'spouse'
                          social_security.dig('spouse', 'socialSecAmt').to_f || 0
                          else
                          social_security['socialSecAmt'].to_f || 0
                          end

          comp = if beneficiary_type == 'spouse'
                      benefits.dig('spouseBenefits', 'compensationAndPension').to_f || 0
                  else
                      income.sum { |item| item['compensationAndPension'].to_f }
                  end

          edu = if beneficiary_type == 'spouse'
                  benefits.dig('spouseBenefits', 'education').to_f || 0
                  else
                  income.sum { |item| item['education'].to_f }
                  end

          benefits_amount = comp + edu

          deductions = if enhanced_fsr_active
                          employment_records
                          .select { |emp| emp['isCurrent'] }
                          .map { |emp| 
                            if emp['deductions'].nil?
                              0
                            else
                              emp['deductions']
                            end
                          }
                          .flatten
                        else
                          curr_employment.pluck('deductions').flatten
                        end

          gross_salary = gross_salary.to_f.round(2)
          taxes_values = filter_reduce_by_name(deductions, @tax_filters)
          retirement_values = filter_reduce_by_name(deductions, @retirement_filters)
          social_sec = filter_reduce_by_name(deductions, @social_sec_filters)
          other = other_deductions_amt(deductions, @all_filters)
          tot_deductions = taxes_values + retirement_values + social_sec + other
          other_income = addl_inc.to_f.round(2) + benefits_amount.to_f.round(2) + soc_sec_amt.to_f.round(2)
          net_income = gross_salary - tot_deductions
          total_monthly_net_income = net_income + other_income

          {
              grossSalary: gross_salary,
              deductions: {
              taxes: taxes_values,
              retirement: retirement_values,
              socialSecurity: social_sec,
              otherDeductions: {
                  name: other_deductions_name(deductions, @all_filters),
                  amount: other
              }
              },
              totalDeductions: tot_deductions,
              netTakeHomePay: net_income,
              otherIncome: {
              name: name_str(soc_sec_amt, comp, edu, addl_inc_records),
              amount: other_income.round(2)
              },
              totalMonthlyNetIncome: total_monthly_net_income.round(2)
          }
        end
      end
    end
  end
end
