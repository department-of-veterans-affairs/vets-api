# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

RSpec.describe TravelPay::V0::ExpensesController, type: :request do
  let(:user) { build(:user) }
  let(:claim_id) { SecureRandom.uuid }

  before do
    sign_in(user)
    allow(Flipper).to receive(:enabled?).with(:travel_pay_power_switch, instance_of(User)).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_complex_claims, instance_of(User)).and_return(true)
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

    let(:auth_manager) { instance_double(TravelPay::AuthManager) }
    let(:expenses_service) { instance_double(TravelPay::ExpensesService) }

    before do
      allow(TravelPay::AuthManager).to receive(:new).and_return(auth_manager)
      allow(TravelPay::ExpensesService).to receive(:new).with(auth_manager).and_return(expenses_service)
    end

    context 'when creating a valid expense' do
      let(:expected_response) do
        {
          'id' => SecureRandom.uuid,
          'expense_type' => 'other',
          'claim_id' => claim_id,
          'description' => 'Test expense description',
          'cost_requested' => 25.50,
          'status' => 'created'
        }
      end

      before do
        allow(expenses_service).to receive(:create_expense).and_return(expected_response)
      end

      it 'creates an expense successfully' do
        post "/travel_pay/v0/claims/#{claim_id}/expenses/other",
             params: expense_params,
             headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:created)
        response_body = JSON.parse(response.body)
        expect(response_body['expense_type']).to eq('other')
        expect(response_body['claim_id']).to eq(claim_id)
        expect(response_body['description']).to eq('Test expense description')
      end

      it 'calls the expenses service with correct parameters' do
        expected_service_params = {
          'claim_id' => claim_id,
          'purchase_date' => expense_params[:expense][:purchase_date],
          'description' => 'Test expense description',
          'cost_requested' => 25.50,
          'expense_type' => 'other'
        }

        expect(expenses_service).to receive(:create_expense).with(expected_service_params)

        post "/travel_pay/v0/claims/#{claim_id}/expenses/other",
             params: expense_params,
             headers: { 'Authorization' => 'Bearer vagov_token' }
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

    context 'for different expense types' do
      it 'accepts other expense type' do
        allow(expenses_service).to receive(:create_expense).and_return({
                                                                         'id' => SecureRandom.uuid,
                                                                         'expense_type' => 'other',
                                                                         'status' => 'created'
                                                                       })

        post "/travel_pay/v0/claims/#{claim_id}/expenses/other",
             params: expense_params,
             headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'GET #show' do
    let(:expense_id) { SecureRandom.uuid }
    let(:auth_manager) { instance_double(TravelPay::AuthManager) }
    let(:expenses_service) { instance_double(TravelPay::ExpensesService) }

    before do
      allow(TravelPay::AuthManager).to receive(:new).and_return(auth_manager)
      allow(TravelPay::ExpensesService).to receive(:new).with(auth_manager).and_return(expenses_service)
    end

    context 'when retrieving a valid expense' do
      let(:expected_response) do
        {
          'id' => expense_id,
          'expense_type' => 'other',
          'claim_id' => claim_id,
          'description' => 'Test other expense',
          'cost_requested' => 45.25,
          'status' => 'approved'
        }
      end

      before do
        allow(expenses_service).to receive(:get_expense).and_return(expected_response)
      end

      it 'retrieves an expense successfully' do
        get "/travel_pay/v0/claims/#{claim_id}/expenses/other/#{expense_id}",
            headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body['id']).to eq(expense_id)
        expect(response_body['expense_type']).to eq('other')
        expect(response_body['claim_id']).to eq(claim_id)
      end

      it 'calls the expenses service with correct parameters' do
        expect(expenses_service).to receive(:get_expense).with('other', expense_id)

        get "/travel_pay/v0/claims/#{claim_id}/expenses/other/#{expense_id}",
            headers: { 'Authorization' => 'Bearer vagov_token' }
      end
    end

    context 'when expense_id is blank' do
      it 'returns bad request status' do
        get "/travel_pay/v0/claims/#{claim_id}/expenses/other/%20",
            headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:bad_request)
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

    context 'for different expense types' do
      it 'accepts other expense type' do
        allow(expenses_service).to receive(:get_expense).and_return({
                                                                      'id' => expense_id,
                                                                      'expense_type' => 'other',
                                                                      'status' => 'approved'
                                                                    })

        get "/travel_pay/v0/claims/#{claim_id}/expenses/other/#{expense_id}",
            headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when expense is not found' do
      before do
        allow(expenses_service).to receive(:get_expense).and_raise(
          Common::Exceptions::RecordNotFound.new(expense_id)
        )
      end

      it 'returns not found status' do
        get "/travel_pay/v0/claims/#{claim_id}/expenses/other/#{expense_id}",
            headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
