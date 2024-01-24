# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DebtsApi::V0::FinancialStatusReportsCalculationsController, type: :controller do
  let(:user) { build(:user, :loa3) }
  let(:valid_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_calculations_form') }

  before do
    sign_in_as(user)
    populate_monthly_income
  end

  def populate_monthly_income
    calculations_controller = described_class.new
    @monthly_income = calculations_controller.monthly_income(valid_form_data['data'])
  end

  describe '#calculate_income' do
    it 'calculates monthly income' do
      expect(@monthly_income).not_to be_nil
    end

    it 'has vets income' do
      vets_income = @monthly_income[:vetIncome]
      expect(vets_income).not_to be_nil
    end

    it 'has spouse income' do
      sp_income = @monthly_income[:spIncome]
      expect(sp_income).not_to be_nil
    end

    it 'has vets gross salary' do
      vets_income = @monthly_income[:vetIncome]
      gross_salary = vets_income[:grossSalary]
      expect(gross_salary).not_to be_nil
    end

    it 'has spouse gross salary' do
      sp_income = @monthly_income[:spIncome]
      sp_gross_salary = sp_income[:grossSalary]
      expect(sp_gross_salary).not_to be_nil
    end

    it 'has vets other deductions' do
      vet_income = @monthly_income[:vetIncome]
      deductions = vet_income[:deductions]
      other_deductions = deductions[:otherDeductions]
      expect(other_deductions).not_to be_nil
    end

    it 'has vets total deductions' do
      vets_income = @monthly_income[:vetIncome]
      total_deductions = vets_income[:totalDeductions]
      expect(total_deductions).not_to be_nil
      expect(total_deductions).to be > 0
    end

    it 'has spouse deductions' do
      sp_income = @monthly_income[:spIncome]
      deductions = sp_income[:deductions]
      expect(deductions).not_to be_nil
    end

    it 'has spouse total deductions' do
      sp_income = @monthly_income[:spIncome]
      total_deductions = sp_income[:totalDeductions]
      expect(total_deductions).not_to be_nil
      expect(total_deductions).to be > 0
    end

    it 'has vets net take home pay' do
      vets_income = @monthly_income[:vetIncome]
      net_take_home_pay = vets_income[:netTakeHomePay]
      expect(net_take_home_pay).not_to be_nil
      expect(net_take_home_pay).to be > 0
      expect(net_take_home_pay).to eq(5608.66)
    end

    it 'has vets other income' do
      vets_income = @monthly_income[:vetIncome]
      other_income = vets_income[:otherIncome]
      expect(other_income).not_to be_nil
    end

    it 'has vets total monthly net income' do
      vets_income = @monthly_income[:vetIncome]
      total_monthly_net_income = vets_income[:totalMonthlyNetIncome]
      expect(total_monthly_net_income).not_to be_nil
      expect(total_monthly_net_income).to be > 0
    end

    it 'has spouse net take home pay' do
      sp_income = @monthly_income[:spIncome]
      net_take_home_pay = sp_income[:netTakeHomePay]
      expect(net_take_home_pay).not_to be_nil
      expect(net_take_home_pay).to be > 0
      expect(net_take_home_pay).to eq(4065.08)
    end

    it 'has spouse other income' do
      sp_income = @monthly_income[:spIncome]
      other_income = sp_income[:otherIncome]
      expect(other_income).not_to be_nil
    end

    it 'has spouse total monthly net income' do
      sp_income = @monthly_income[:spIncome]
      total_monthly_net_income = sp_income[:totalMonthlyNetIncome]
      expect(total_monthly_net_income).not_to be_nil
      expect(total_monthly_net_income).to be > 0
    end

    it 'checks if vets gross salary is populated' do
      vets_income = @monthly_income[:vetIncome]
      gross_salary = vets_income[:grossSalary]
      expect(gross_salary).to be > 0
    end

    it 'checks if vets gross salary is calcualted correctly' do
      vets_income = @monthly_income[:vetIncome]
      gross_salary = vets_income[:grossSalary]
      expect(gross_salary).to eq(7001.1)
    end

    it 'checks if spouse gross salary is populated' do
      sp_income = @monthly_income[:spIncome]
      gross_salary = sp_income[:grossSalary]
      expect(gross_salary).to be > 0
    end

    it 'checks if spouse gross salary is calcualted correctly' do
      sp_income = @monthly_income[:spIncome]
      gross_salary = sp_income[:grossSalary]
      expect(gross_salary).to eq(5000.54)
    end

    it 'has vets deductions' do
      vets_income = @monthly_income[:vetIncome]
      deductions = vets_income[:deductions]
      expect(deductions).not_to be_nil
    end

    it 'checks if vets deduction taxes are calculated correctly' do
      vets_income = @monthly_income[:vetIncome]
      deductions = vets_income[:deductions]
      taxes = deductions[:taxes]
      expect(taxes).to eq(781.03)
    end

    it 'checks if spouse deduction taxes are calculated correctly' do
      sp_income = @monthly_income[:spIncome]
      sp_deductions = sp_income[:deductions]
      taxes = sp_deductions[:taxes]
      expect(taxes).to eq(581.01)
    end

    it 'checks if vets deduction social security is calculated correctly' do
      vets_income = @monthly_income[:vetIncome]
      deductions = vets_income[:deductions]
      social_security = deductions[:socialSecurity]
      expect(social_security).to eq(122.4)
    end

    it 'checks if spouse deduction social security is calculated correctly' do
      sp_income = @monthly_income[:spIncome]
      deductions = sp_income[:deductions]
      social_security = deductions[:socialSecurity]
      expect(social_security).to eq(0)
    end

    it 'checks if vets other deductions are calculated correctly' do
      vets_income = @monthly_income[:vetIncome]
      deductions = vets_income[:deductions]
      other_deductions = deductions[:otherDeductions]
      expect(other_deductions[:amount]).to eq(389.01)
    end

    it 'checks if spouse other deductions are calculated correctly' do
      sp_income = @monthly_income[:spIncome]
      deductions = sp_income[:deductions]
      other_deductions = deductions[:otherDeductions]
      expect(other_deductions[:amount]).to eq(254.45)
    end

    it 'checks if vets total deductions is calculated correctly' do
      vets_income = @monthly_income[:vetIncome]
      total_deductions = vets_income[:totalDeductions]
      expect(total_deductions).to eq(1392.44)
    end

    it 'checks if spouse total deductions is calculated correctly' do
      sp_income = @monthly_income[:spIncome]
      total_deductions = sp_income[:totalDeductions]
      expect(total_deductions).to eq(935.46)
    end

    it 'checks if vets other income is calculated correctly' do
      vets_income = @monthly_income[:vetIncome]
      other_income = vets_income[:otherIncome]
      expect(other_income[:amount]).to eq(7012.85)
    end

    it 'checks if spouse other income is calculated correctly' do
      sp_income = @monthly_income[:spIncome]
      other_income = sp_income[:otherIncome]
      expect(other_income[:amount]).to eq(4701.77)
    end

    it 'checks if vets total monthly net income is calculated correctly' do
      vets_income = @monthly_income[:vetIncome]
      total_monthly_net_income = vets_income[:totalMonthlyNetIncome]
      expect(total_monthly_net_income).to eq(12_621.51)
    end

    it 'checks if spouse total monthly net income is calculated correctly' do
      sp_income = @monthly_income[:spIncome]
      total_monthly_net_income = sp_income[:totalMonthlyNetIncome]
      expect(total_monthly_net_income).to eq(8766.85)
    end

    it 'checks if total (spounse + vet) monthly net income is calculated correctly' do
      total_monthly_net_income = @monthly_income[:totalMonthlyNetIncome]
      expect(total_monthly_net_income).to eq(21_388.36)
    end
  end
end
