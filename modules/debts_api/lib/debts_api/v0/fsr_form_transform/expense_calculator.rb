# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/enhanced_expense_calculator'
require 'debts_api/v0/fsr_form_transform/old_expense_calculator'

module DebtsApi
  module V0
    module FsrFormTransform
      class ExpenceCalculator
        def self.build(form)
          enhanced = form['view:enhancedFinancialStatusReport'] || false
          enhanced ? EnhancedExpenceCalculator.new(form) : OldExpenceCalculator.new(form)
        end
      end
    end
  end
end
