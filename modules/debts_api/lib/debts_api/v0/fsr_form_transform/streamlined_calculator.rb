# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/gmt_calculator'
require 'debts_api/v0/fsr_form_transform/income_calculator'
require 'debts_api/v0/fsr_form_transform/asset_calculator'
require 'debts_api/v0/fsr_form_transform/enhanced_expense_calculator'
require 'debts_api/v0/fsr_form_transform/utils'

module DebtsApi
  module V0
    module FsrFormTransform
      class StreamlinedCalculator
        include ::FsrFormTransform::Utils
        VHA_LIMIT = 5000

        def initialize(form)
          @form = form
          @gmt_data = @form['gmt_data']
          @income_data = DebtsApi::V0::FsrFormTransform::IncomeCalculator.new(form).get_monthly_income
          @asset_data = DebtsApi::V0::FsrFormTransform::AssetCalculator.new(form).transform_assets
          @enhanced_expense_calculator = DebtsApi::V0::FsrFormTransform::EnhancedExpenseCalculator.new(
            re_camel(form)
          ).transform_expenses
        end

        def get_streamlined_data
          update_streamlined_tracking_metrics

          {
            'value' => streamlined_short_form? || streamlined_long_form?,
            'type' => if streamlined_short_form?
                        'short'
                      elsif streamlined_long_form?
                        'long'
                      else
                        'none'
                      end
          }
        end

        private

        def total_annual_income
          vet_income = @income_data.dig(:vetIncome, :totalMonthlyNetIncome).to_f
          spouse_income = @income_data.dig(:spIncome, :totalMonthlyNetIncome).to_f
          total_income = (vet_income + spouse_income)
          total_income * 12
        end

        def total_discretionary_income
          monthly_net_income = @income_data[:totalMonthlyNetIncome]
          monthly_expenses = @enhanced_expense_calculator['totalMonthlyExpenses']&.to_f

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

        def streamlined_short_form?
          return false unless eligible_for_streamlined? && income_below_gmt_threshold?

          if streamlined_waiver_asset_update?
            are_liquid_assets_below_gmt_threshold?
          else
            cash_below_gmt_threshold?
          end
        end

        def streamlined_long_form?
          return false unless eligible_for_streamlined? && are_liquid_assets_below_gmt_threshold?

          !income_below_gmt_threshold? && income_below_upper_threshold? && income_below_discretionary_threshold?
        end

        def eligible_for_streamlined?
          return false if @form['selected_debts_and_copays'].empty?

          debt_below_vha_limit? && total_waiver_and_copay_debts
        end

        def update_streamlined_tracking_metrics
          tracking_label = "full_transform.#{streamlined? ? 'has' : 'no'}_streamlined_data"
          StatsD.increment("#{DebtsApi::V0::Form5655Submission::STATS_KEY}.#{tracking_label}")
        end

        def are_liquid_assets_below_gmt_threshold?
          return false if @gmt_data['gmt_threshold'].blank?

          liquid_assets = @asset_data['cashOnHand'].to_f + @asset_data['cashInBank'].to_f
          liquid_assets < @gmt_data['gmt_threshold']
        end

        def income_below_gmt_threshold?
          return false if @gmt_data['gmt_threshold'].blank?

          total_annual_income < @gmt_data['gmt_threshold']
        end

        def cash_below_gmt_threshold?
          return false if @gmt_data['gmt_threshold'].blank?

          @asset_data['cashOnHand'].to_f < @gmt_data['gmt_threshold']
        end

        def streamlined_waiver_asset_update?
          @form['view:streamlined_waiver_asset_update']
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

        def streamlined?
          streamlined_short_form? || streamlined_long_form?
        end
      end
    end
  end
end
