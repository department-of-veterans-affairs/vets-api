# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

RSpec.describe TravelPay::V0::ExpensesController, type: :request do
  let(:user) { build(:user) }
  let(:claim_id) { '3fa85f64-5717-4562-b3fc-2c963f66afa6' }
  let(:expense_id) { '123e4567-e89b-12d3-a456-426614174500' }

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

  # POST /travel_pay/v0/claims/:claim_id/expenses/:expense_type
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
        VCR.use_cassette('travel_pay/expenses/create/200_other_success') do
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

  # GET /travel_pay/v0/claims/:claim_id/expenses/:expense_type/:expense_id
  describe 'GET #show' do
    let(:expense_id) { '550e8400-e29b-41d4-a716-446655440000' }

    context 'when retrieving a valid expense' do
      it 'retrieves an expense successfully', :vcr do
        VCR.use_cassette('travel_pay/expenses/get/200_other_success') do
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
  end

  # DELETE /travel_pay/v0/expenses/:expense_type/:expense_id
  describe 'DELETE #destroy' do
    context 'when feature flag is enabled' do
      context 'vcr tests' do
        context 'when the expense is successfully deleted' do
          it 'returns the expense data for expense type: other' do
            VCR.use_cassette('travel_pay/expenses/delete/200_other_ok', match_requests_on: %i[method path]) do
              delete(expense_path('other'))

              expect(response).to have_http_status(:ok)
              body = JSON.parse(response.body)

              expect(body['expenseId']).to eq(expense_id)
            end
          end

          it 'returns the expense data for expense type: mileage' do
            VCR.use_cassette('travel_pay/expenses/delete/200_mileage_ok', match_requests_on: %i[method path]) do
              delete(expense_path('mileage'))

              expect(response).to have_http_status(:ok)
              body = JSON.parse(response.body)

              expect(body['expenseId']).to eq(expense_id)
            end
          end

          it 'returns the expense data for expense type: parking' do
            VCR.use_cassette('travel_pay/expenses/delete/200_parking_ok', match_requests_on: %i[method path]) do
              delete(expense_path('parking'))

              expect(response).to have_http_status(:ok)
              body = JSON.parse(response.body)

              expect(body['expenseId']).to eq(expense_id)
            end
          end

          it 'returns the expense data for expense type: meal' do
            VCR.use_cassette('travel_pay/expenses/delete/200_meal_ok', match_requests_on: %i[method path]) do
              delete(expense_path('meal'))

              expect(response).to have_http_status(:ok)
              body = JSON.parse(response.body)

              expect(body['expenseId']).to eq(expense_id)
            end
          end
        end
      end

      context 'with stubbed service' do
        let(:expenses_service) { instance_double(TravelPay::ExpensesService) }

        before do
          allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize).and_return({ veis_token: 'veis_token',
                                                                                            btsss_token: 'btsss_token' })
          allow_any_instance_of(TravelPay::V0::ExpensesController).to receive(:current_user).and_return(user)
          allow(TravelPay::ExpensesService).to receive(:new).and_return(expenses_service)
        end

        it 'returns bad request for invalid expense_id' do
          delete(expense_path('other', 'invalid-uuid'))

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['errors'].first['detail']).to include('Expense ID is invalid')
        end

        it 'returns bad request for invalid expense_type' do
          delete(expense_path('invalid_type'))

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['errors'].first['detail']).to include('Invalid expense type')
        end

        it 'returns not found when the expense does not exist' do
          allow(expenses_service).to receive(:delete_expense).and_raise(
            Common::Exceptions::BackendServiceException.new(
              nil,
              { source: 'BTSSS', code: 404, detail: 'Expense not found' },
              404
            )
          )
          delete(expense_path('other'))

          expect(response).to have_http_status(:not_found)
          body = JSON.parse(response.body)
          expect(body['error']).to include('Error deleting expense')
        end
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_complex_claims, instance_of(User)).and_return(false)
      end

      it 'returns service unavailable' do
        delete(expense_path('other'))

        expect(response).to have_http_status(:service_unavailable)
        body = JSON.parse(response.body)
        expect(body['errors'].first['detail']).to include('Travel Pay expense endpoint unavailable per feature toggle')
      end
    end
  end

  def expense_path(expense_type, id = nil)
    "/travel_pay/v0/expenses/#{expense_type}/#{id || expense_id}"
  end
end
