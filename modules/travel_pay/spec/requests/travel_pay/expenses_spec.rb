# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

RSpec.describe TravelPay::V0::ExpensesController, type: :request do
  let(:user) { build(:user) }
  let(:claim_id) { '3fa85f64-5717-4562-b3fc-2c963f66afa6' }

  before do
    sign_in(user)
    allow(Flipper).to receive(:enabled?).with(:travel_pay_power_switch, instance_of(User)).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_complex_claims, instance_of(User)).and_return(true)

    # Mock authentication to provide tokens for VCR cassettes
    auth_manager_double = instance_double(
      TravelPay::AuthManager,
      authorize: {
        veis_token: 'veis_access_token_12345',
        btsss_token: 'btsss_access_token_67890'
      }
    )
    allow(TravelPay::AuthManager).to receive(:new).and_return(auth_manager_double)
  end

  describe 'POST #create' do
    let(:expense_params) do
      {
        expense: {
          purchase_date: 1.day.ago.iso8601,
          description: 'Test expense description',
          cost_requested: 25.50
        }
      }
    end

    context 'when creating a valid expense' do
      it 'creates an expense successfully', :vcr do
        VCR.use_cassette('travel_pay/expenses/create_other_expense_success') do
          post "/travel_pay/v0/claims/#{claim_id}/expenses/other",
               params: expense_params,
               headers: { 'Authorization' => 'Bearer vagov_token' }

          expect(response).to have_http_status(:created)
          response_body = JSON.parse(response.body)
          expect(response_body).to have_key('id')
          expect(response_body).to have_key('expenseType')
          expect(response_body).to have_key('description')
        end
      end
    end

    context 'when expense validation fails' do
      let(:invalid_expense_params) do
        {
          expense: {
            description: 'Test expense description'
            # Missing required fields: purchase_date, cost_requested
          }
        }
      end

      it 'returns unprocessable entity status with validation errors' do
        post "/travel_pay/v0/claims/#{claim_id}/expenses/other",
             params: invalid_expense_params,
             headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:unprocessable_entity)
        response_body = JSON.parse(response.body)
        expect(response_body['errors']).to be_present
        expect(response_body['errors'].first['detail']).to include("can't be blank")
      end
    end

    context 'when claim_id is blank' do
      it 'returns bad request status' do
        post '/travel_pay/v0/claims/%20/expenses/other',
             params: expense_params,
             headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when expense_type is invalid' do
      it 'returns bad request status for invalid expense type' do
        post "/travel_pay/v0/claims/#{claim_id}/expenses/invalid_type",
             params: expense_params,
             headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:bad_request)
        response_body = JSON.parse(response.body)
        expect(response_body['errors'].first['detail']).to include('Invalid expense type')
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(
          :travel_pay_enable_complex_claims,
          instance_of(User)
        ).and_return(false)
      end

      it 'returns service unavailable status' do
        post "/travel_pay/v0/claims/#{claim_id}/expenses/other",
             params: expense_params,
             headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end

  describe 'GET #show' do
    let(:expense_id) { '550e8400-e29b-41d4-a716-446655440000' }

    context 'when retrieving a valid expense' do
      it 'retrieves an expense successfully', :vcr do
        VCR.use_cassette('travel_pay/expenses/get_other_expense_success') do
          get "/travel_pay/v0/claims/#{claim_id}/expenses/other/#{expense_id}",
              headers: { 'Authorization' => 'Bearer vagov_token' }

          expect(response).to have_http_status(:ok)
          response_body = JSON.parse(response.body)
          expect(response_body).to have_key('id')
          expect(response_body).to have_key('expenseType')
          expect(response_body).to have_key('description')
        end
      end
    end

    context 'when expense_id is malformed' do
      it 'returns bad request status' do
        get "/travel_pay/v0/claims/#{claim_id}/expenses/other/%20",
            headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when expense_id is missing' do
      it 'returns bad request status' do
        get "/travel_pay/v0/claims/#{claim_id}/expenses/other",
            headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when expense_id is not a valid UUID' do
      it 'returns bad request status for invalid UUID format' do
        invalid_expense_id = 'not-a-valid-uuid'

        get "/travel_pay/v0/claims/#{claim_id}/expenses/other/#{invalid_expense_id}",
            headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:bad_request)
        response_body = JSON.parse(response.body)
        expect(response_body['errors'].first['detail']).to eq('Expense ID is invalid')
      end

      it 'returns bad request status for malformed UUID' do
        malformed_expense_id = '12345678-1234-1234-1234-12345678901' # Missing one character

        get "/travel_pay/v0/claims/#{claim_id}/expenses/other/#{malformed_expense_id}",
            headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:bad_request)
        response_body = JSON.parse(response.body)
        expect(response_body['errors'].first['detail']).to eq('Expense ID is invalid')
      end

      it 'returns bad request status for UUID with invalid version' do
        invalid_version_uuid = '12345678-1234-1234-7234-123456789012' # Version 7 UUID (not in range 8-D)

        get "/travel_pay/v0/claims/#{claim_id}/expenses/other/#{invalid_version_uuid}",
            headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:bad_request)
        response_body = JSON.parse(response.body)
        expect(response_body['errors'].first['detail']).to eq('Expense ID is invalid')
      end
    end

    context 'when expense_type is invalid' do
      it 'returns bad request status for invalid expense type' do
        get "/travel_pay/v0/claims/#{claim_id}/expenses/invalid_type/#{expense_id}",
            headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:bad_request)
        response_body = JSON.parse(response.body)
        expect(response_body['errors'].first['detail']).to include('Invalid expense type')
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(
          :travel_pay_enable_complex_claims,
          instance_of(User)
        ).and_return(false)
      end

      it 'returns service unavailable status' do
        get "/travel_pay/v0/claims/#{claim_id}/expenses/other/#{expense_id}",
            headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end
end
