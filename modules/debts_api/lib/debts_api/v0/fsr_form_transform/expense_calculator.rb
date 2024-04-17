# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/enhanced_expense_calculator'
require 'debts_api/v0/fsr_form_transform/old_expense_calculator'

module DebtsApi
  module V0
    module FsrFormTransform
      class ExpenseCalculator
        def self.build(form)
          form.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
          enhanced = form['view:enhancedFinancialStatusReport'] || false
          enhanced ? EnhancedExpenseCalculator.new(form) : OldExpenseCalculator.new(form)
        end
      end
    end
  end
end
