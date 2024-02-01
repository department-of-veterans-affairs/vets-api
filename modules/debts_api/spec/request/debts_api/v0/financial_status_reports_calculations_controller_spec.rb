# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DebtsApi::V0::FinancialStatusReportsCalculations requesting', type: :request do
  let(:user) { build(:user, :loa3) }

  let(:maximal_fsr_form_data) do
    get_fixture_absolute('modules/debts_api/spec/fixtures//pre_submission_fsr/fsr_maximal_calculations_form')
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
  end
end
