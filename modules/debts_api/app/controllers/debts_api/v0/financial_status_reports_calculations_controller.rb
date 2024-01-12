# frozen_string_literal: true

require 'debts_api/v0/calculations/calculate_expenses'
require 'debts_api/v0/calculations/calculate_income'

module DebtsApi
  module V0
    class FinancialStatusReportsCalculationsController < ApplicationController
      
      def calculate_monthly_income(calculator, form_data)
        calculator.get_monthly_income(form_data)
      end
    end
  end
end
