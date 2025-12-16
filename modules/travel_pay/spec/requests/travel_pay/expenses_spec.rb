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
        purchase_date: 1.day.ago.iso8601,
        description: 'Test expense description',
        cost_requested: 25.50
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

      it 'transforms receipt parameters before making request' do
        test_claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'

        vets_api_params = {
          'claim_id' => '73611905-71bf-46ed-b1ec-e790593b8565',
          'expense_type' => 'parking',
          'purchase_date' => '2024-10-02',
          'description' => 'Parking fee',
          'cost_requested' => 10.00,
          'receipt' => {
            'file_name' => 'its_a_me',
            'length' => 'mario',
            'content_type' => 'lets_a_go',
            'file_data' => 'luigi'
          }
        }

        expected_request_body = {
          'claimId' => '73611905-71bf-46ed-b1ec-e790593b8565',
          # Gets formatted in the model
          'dateIncurred' => '2024-10-02T00:00:00Z',
          'description' => 'Parking fee',
          'costRequested' => 10.00,
          'expenseType' => 'parking',
          'expenseReceipt' => {
            'fileName' => 'its_a_me',
            'length' => 'mario',
            'contentType' => 'lets_a_go',
            'fileData' => 'luigi'
          }
        }

        expenses_client = instance_double(TravelPay::ExpensesClient)
        allow(TravelPay::ExpensesClient).to receive(:new).and_return(expenses_client)

        expect(expenses_client).to receive(:add_expense)
          .with(anything, anything, 'parking', expected_request_body)
          .and_return({ 'id' => 1234 })

        # allow_any_instance_of(TravelPay::ExpensesService).to receive(:client).and_return(expenses_client)

        post "/travel_pay/v0/claims/#{test_claim_id}/expenses/parking",
             params: vets_api_params,
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

    context 'with receipt attachment' do
      let(:expenses_service) { instance_double(TravelPay::ExpensesService) }
      let(:receipt_hash) do
        {
          'content_type' => 'application/pdf',
          'length' => '1446',
          'file_name' => 'test.pdf',
          'file_data' => Base64.strict_encode64(Rails.root.join('modules', 'travel_pay', 'spec', 'fixtures',
                                                                'documents', 'test.pdf').read)
        }
      end
      let(:expense_params_with_receipt) do
        {
          purchase_date: 1.day.ago.iso8601,
          description: 'Parking with receipt',
          cost_requested: 15.00,
          receipt: receipt_hash
        }
      end

      before do
        allow(TravelPay::ExpensesService).to receive(:new).and_return(expenses_service)
      end

      it 'sends receipt in the correct body structure to create_expense' do
        # Simpler verification - just capture and verify key elements
        received_params = nil
        allow(expenses_service).to receive(:create_expense) do |params|
          received_params = params
          { 'id' => expense_id }
        end

        post "/travel_pay/v0/claims/#{claim_id}/expenses/parking",
             params: expense_params_with_receipt,
             headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:created)

        # Verify receipt structure after the request
        expect(received_params).not_to be_nil
        expect(received_params['receipt']).to be_present
        expect(received_params['receipt']['contentType']).to eq('application/pdf')
        expect(received_params['receipt']['fileData']).to be_present
        expect(received_params['receipt']['length']).to eq('1446')
        expect(received_params['receipt']['fileName']).to eq('test.pdf')
      end

      it 'excludes receipt from body when not provided' do
        expect(expenses_service).to receive(:create_expense) do |params|
          # Verify params structure - should NOT have receipt
          expect(params).to be_a(Hash)
          expect(params['claim_id']).to eq(claim_id)
          expect(params['purchase_date']).to be_a(String)
          expect(params['description']).to eq('Test expense description')
          expect(params['cost_requested']).to eq(25.50)
          expect(params['expense_type']).to eq('other')
          expect(params).not_to have_key('receipt')

          # Return mock response
          { 'id' => expense_id }
        end

        post "/travel_pay/v0/claims/#{claim_id}/expenses/other",
             params: expense_params,
             headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:created)
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

  # PATCH /travel_pay/v0/expenses/:expense_type/:expense_id
  describe 'PATCH #update' do
    let(:expense_params) do
      {
        purchase_date: '2025-09-14T21:02:39.000',
        description: 'Test expense description',
        cost_requested: 25.50
      }
    end

    context 'when updating a valid expense' do
      it 'updates an expense successfully', :vcr do
        VCR.use_cassette('travel_pay/expenses/update/200_other_success') do
          patch '/travel_pay/v0/expenses/other/123e4567-e89b-12d3-a456-426614174500',
                params: expense_params,
                headers: { 'Authorization' => 'Bearer vagov_token' }

          expect(response).to have_http_status(:ok)
          response_body = JSON.parse(response.body)
          expect(response_body['id']).to eq(expense_id)
        end
      end
    end

    context 'when expense validation fails' do
      let(:invalid_expense_params) do
        {
          description: 'Test expense description'
          # Missing required fields: purchase_date, cost_requested
        }
      end

      it 'returns unprocessable entity status with validation errors' do
        patch '/travel_pay/v0/expenses/other/123e4567-e89b-12d3-a456-426614174500',
              params: invalid_expense_params,
              headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:unprocessable_entity)
        response_body = JSON.parse(response.body)
        expect(response_body['errors']).to be_present
        expect(response_body['errors'].first['detail']).to include("can't be blank")
      end
    end

    context 'when expense_type is invalid' do
      it 'returns bad request' do
        patch '/travel_pay/v0/expenses/invalid_type/123e4567-e89b-12d3-a456-426614174500', params: expense_params
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when expense_id is invalid' do
      it 'returns bad request' do
        patch '/travel_pay/v0/expenses/other/invalid-uuid', params: expense_params
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when request body is empty' do
      it 'returns bad request' do
        patch expense_path('other'), params: {}
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:travel_pay_enable_complex_claims, instance_of(User))
          .and_return(false)
      end

      it 'returns service unavailable' do
        patch expense_path('other'), params: expense_params
        expect(response).to have_http_status(:service_unavailable)
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

              expect(body['id']).to eq(expense_id)
            end
          end

          it 'returns the expense data for expense type: mileage' do
            VCR.use_cassette('travel_pay/expenses/delete/200_mileage_ok', match_requests_on: %i[method path]) do
              delete(expense_path('mileage'))

              expect(response).to have_http_status(:ok)
              body = JSON.parse(response.body)

              expect(body['id']).to eq(expense_id)
            end
          end

          it 'returns the expense data for expense type: parking' do
            VCR.use_cassette('travel_pay/expenses/delete/200_parking_ok', match_requests_on: %i[method path]) do
              delete(expense_path('parking'))

              expect(response).to have_http_status(:ok)
              body = JSON.parse(response.body)

              expect(body['id']).to eq(expense_id)
            end
          end

          it 'returns the expense data for expense type: meal' do
            VCR.use_cassette('travel_pay/expenses/delete/200_meal_ok', match_requests_on: %i[method path]) do
              delete(expense_path('meal'))

              expect(response).to have_http_status(:ok)
              body = JSON.parse(response.body)

              expect(body['id']).to eq(expense_id)
            end
          end
        end
      end

      context 'with stubbed service' do
        let(:expenses_service) { instance_double(TravelPay::ExpensesService) }

        before do
          allow_any_instance_of(TravelPay::AuthManager)
            .to receive(:authorize).and_return({ veis_token: 'veis_token',
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
        allow(Flipper).to receive(:enabled?)
          .with(:travel_pay_enable_complex_claims, instance_of(User)).and_return(false)
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
