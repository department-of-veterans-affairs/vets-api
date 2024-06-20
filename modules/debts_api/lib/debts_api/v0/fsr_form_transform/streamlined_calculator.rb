# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/gmt_calculator'
require 'debts_api/v0/fsr_form_transform/income_calculator'
require 'debts_api/v0/fsr_form_transform/asset_calculator'
require 'debts_api/v0/fsr_form_transform/enhanced_expense_calculator'

module DebtsApi
  module V0
    module FsrFormTransform
      class StreamlinedCalculator
        VHA_LIMIT = 5000

        def initialize(form)
          @form = form
          @gmt_data = @form['gmt_data'] #get_gmt_data
          @income_data = DebtsApi::V0::FsrFormTransform::IncomeCalculator.new(form).get_monthly_income
          @asset_data = DebtsApi::V0::FsrFormTransform::AssetCalculator.new(form).transform_assets
          @enhanced_expense_calculator =
            DebtsApi::V0::FsrFormTransform::EnhancedExpenseCalculator.new(form).transform_expenses
        end

        def get_streamlined_data
          value = false
          type = 'none'

          if streamlined_short_form?
            value = true
            type = 'short'
          elsif streamlined_long_form?
            value = true
            type = 'long'
          end

          {
            'value' => value,
            'type' => type
          }
        end

        private

        def streamlined_short_form?
          return false unless eligible_for_streamlined? && income_below_gmt_threshold?

          asset_waiver_low_liquid_assets = streamlined_waiver_asset_update? && are_liquid_assets_below_gmt_threshold?
          cash_below_gmt_threshold? || asset_waiver_low_liquid_assets
        end

        def streamlined_long_form?
          return false unless eligible_for_streamlined? && are_liquid_assets_below_gmt_threshold?

          meets_streamlined_long_form_common_conditions? || streamlined_waiver_asset_update?
        end

        def eligible_for_streamlined?
          return false if @form['selected_debts_and_copays'].empty?

          debt_below_vha_limit? && total_waiver_and_copay_debts
        end

        def meets_streamlined_long_form_common_conditions?
          !income_below_gmt_threshold? && income_below_upper_threshold? && income_below_discretionary_threshold?
        end

        def are_liquid_assets_below_gmt_threshold?
          liquid_assets = @asset_data['cashOnHand'] + @asset_data['cashInBank']
          liquid_assets < @gmt_data['gmt_threshold']
        end

        def income_below_gmt_threshold?
          total_annual_income < @gmt_data['gmt_threshold']
        end

        def cash_below_gmt_threshold?
          @asset_data['cashOnHand'] < @gmt_data['gmt_threshold']
        end

        def streamlined_waiver_asset_update?
          @form['view:streamlinedWaiverAssetUpdate']
        end

        def income_below_upper_threshold?
          total_annual_income < @gmt_data['income_upper_threshold']
        end

        def income_below_discretionary_threshold?
          total_discretionary_income < @gmt_data['discretionary_income_threshold']
        end

        def debt_below_vha_limit?
          total_debt < VHA_LIMIT
        end

        def total_annual_income
          @income_data['totalMonthlyNetIncome'] * 12
        end

        def total_discretionary_income
          monthly_net_income = @income_data['totalMonthlyNetIncome']
          monthly_expenses = @enhanced_expense_calculator['totalMonthlyExpenses']

          monthly_net_income - monthly_expenses
        end

        def total_waiver_and_copay_debts
          all_debt_types_copay = @form['selected_debts_and_copays'].all? { |debt| debt['debt_type'] == 'COPAY' }
          @form['view:streamlined_waiver'] && all_debt_types_copay
        end

        def total_debt
          @form['selected_debts_and_copays'].reduce(0) { |total_debt, debt| total_debt + (debt['current_ar'] || 0.0) }
          # TODO: check if current_ar is eq to pHAmtDue
        end

        def get_gmt_data
          dependents = @form['questions']['has_dependents']
          zipcode = @form['personal_data']['veteran_contact_information']['address']['zip_code']
          year = @form['personal_data']['veteran_contact_information']['address']['created_at'].to_datetime.year
          DebtsApi::V0::FsrFormTransform::GmtCalculator.new(year:, dependents:, zipcode:)
        end
      end
    end
  end
end
