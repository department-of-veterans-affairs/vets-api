# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DebtsApi::V0::FinancialStatusReportsCalculationsController, type: :controller do
  let(:user) { build(:user, :loa3) }
  let(:valid_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_calculations_form') }

  before do
    sign_in_as(user)
  end

  describe '#calculate_income' do
    it 'calculates monthly income' do
      income_calculator = DebtsApi::V0::CalculateIncomeCalculations.new
      calculations_controller = described_class.new
      calculations_controller.calculate_monthly_income(income_calculator, valid_form_data)
    end
  end
end
