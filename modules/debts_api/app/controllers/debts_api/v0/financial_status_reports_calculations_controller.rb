# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/income_calculator'

module DebtsApi
  module V0
    class FinancialStatusReportsCalculationsController < ApplicationController
      
      def calculate_monthly_income(calculator, form_data)
        calculator.get_monthly_income(form_data)
      end
    end
  end
end
