# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/asset_calculator'
require 'debts_api/v0/fsr_form_transform/expense_calculator'
require 'debts_api/v0/fsr_form_transform/income_calculator'

module DebtsApi
  module V0
    module FsrFormTransform
      class FullTransformService
        attr_reader => form

        def initialize(form)
          @form = form
          @assets = AssetCalculator.new(@form).transform_assets
          @income = IncomeCalculator.new(@form).get_transformed_income
          @expenses = ExpenseCalculator.build(@form).transform_expenses
        end

        def transform
          output = {}
          output['income'] = @income
          output['assets'] = @assets
          output['expenses'] = @expenses
          output
        end
      end
    end
  end
end
