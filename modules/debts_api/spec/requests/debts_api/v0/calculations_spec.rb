# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DebtsApi::V0::Calculations', type: :request do
  let(:user) { build(:user, :loa3) }
  let(:fsr_form_data) do
    get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/enhanced_fsr_expenses')
  end
  let(:fsr_assets_form) do
    get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/fsr_assets_form')
  end
  let(:maximal_fsr_form_data) do
    get_fixture_absolute('modules/debts_api/spec/fixtures//pre_submission_fsr/fsr_maximal_calculations_form')
  end
  let(:enhanced_expenses) do
    get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/enhanced_fsr_expenses')
  end
  let(:andrew_expenses) do
    get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/andrew_fsr_expenses')
  end
  let(:andrew_two) do
    get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/andrew_fsr_2')
  end
  let(:andrew_three) do
    get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/andrew_fsr_3')
  end
  let(:andrew_to_the_max) do
    get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/andrew_maximal')
  end
  let(:old_expenses) do
    get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/non_enhanced_fsr_expenses')
  end

  before do
    sign_in_as(user)
  end

  describe '#monthly_income' do
    context 'with valid fsr form data' do
      it 'returns monthly income' do
        post('/debts_api/v0/calculate_monthly_income', params: maximal_fsr_form_data.to_h, as: :json)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with andrew fsr form data' do
      it 'returns monthly income' do
        post('/debts_api/v0/calculate_monthly_income', params: andrew_expenses.to_h, as: :json)
        expect(response).to have_http_status(:ok)
      end

      it 'behaves like the FE' do
        post('/debts_api/v0/calculate_monthly_income', params: andrew_two.to_h, as: :json)
        expect(response).to have_http_status(:ok)

        vet_other_income = JSON.parse(response.body)['vetIncome']['otherIncome']
        expect(vet_other_income['name']).to eq('Social Security')
        expect(vet_other_income['amount']).to eq(500)

        spouse_other_income = JSON.parse(response.body)['spIncome']['otherIncome']
        expect(spouse_other_income['name']).to eq('Disability Compensation, Education, Caretaker income')
        expect(spouse_other_income['amount']).to eq(600)

        expect(JSON.parse(response.body)['spIncome']['totalMonthlyNetIncome']).to eq(1600)
        expect(JSON.parse(response.body)['totalMonthlyNetIncome']).to eq(3100)
      end
    end
  end

  describe '#total_assets' do
    context 'with fsr asset form' do
      it 'calculates and returns total asset value' do
        post('/debts_api/v0/calculate_total_assets', params: fsr_assets_form.to_h, as: :json)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with andrew fsr form data' do
      it 'calculates and returns total asset value' do
        post('/debts_api/v0/calculate_total_assets', params: andrew_expenses.to_h, as: :json)
        expect(response).to have_http_status(:ok)
      end

      it 'behaves like FE' do
        post('/debts_api/v0/calculate_total_assets', params: andrew_three.to_h, as: :json)
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to eq({ 'calculatedTotalAssets' => 2780.35 })
      end
    end
  end

  describe '#all_expenses' do
    context 'with enhanced form params' do
      it 'returns all expenses' do
        post('/debts_api/v0/calculate_all_expenses', params: enhanced_expenses.to_h, as: :json)
        expect(response).to have_http_status(:ok)
      end

      it 'takes andrews params' do
        post('/debts_api/v0/calculate_all_expenses', params: andrew_expenses.to_h, as: :json)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with old form params' do
      it 'returns all expenses' do
        post('/debts_api/v0/calculate_all_expenses', params: old_expenses.to_h, as: :json)
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe '#monthly_expenses' do
    context 'with enhanced form params' do
      it 'returns all expenses' do
        post('/debts_api/v0/calculate_monthly_expenses', params: enhanced_expenses.to_h, as: :json)
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to eq({ 'calculatedMonthlyExpenses' => 19_603.44 })
      end
    end

    context 'with old form params' do
      it 'returns all expenses' do
        post('/debts_api/v0/calculate_monthly_expenses', params: old_expenses.to_h, as: :json)
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
