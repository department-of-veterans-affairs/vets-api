# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

RSpec.describe TravelPay::V0::ClaimsController, type: :request do
  let(:user) { build(:user) }

  before do
    sign_in(user)
  end

  describe '#index' do
    context 'successful response from API' do
      let(:expected_claim_ids) do
        %w[
          claim_id_1
          claim_id_2
          claim_id_3
        ]
      end

      it 'responds with 200' do
        VCR.use_cassette('travel_pay/200_claims', match_requests_on: %i[method path]) do
          get '/travel_pay/v0/claims', params: nil, headers: { 'Authorization' => 'Bearer vagov_token' }
          expect(response).to have_http_status(:ok)
          claim_ids = JSON.parse(response.body)['data'].pluck('id')

          expect(claim_ids).to eq(expected_claim_ids)
        end
      end

      context 'filtering claims' do
        it 'returns a subset of claims' do
          params = { 'appt_datetime' => '2024-04-09' }
          headers = { 'Authorization' => 'Bearer vagov_token' }

          VCR.use_cassette('travel_pay/200_claims', match_requests_on: %i[method path]) do
            get('/travel_pay/v0/claims', params:, headers:)
            expect(response).to have_http_status(:ok)
            claim_ids = JSON.parse(response.body)['data'].pluck('id')
            expect(claim_ids.length).to eq(1)
            expect(claim_ids[0]).to eq('claim_id_2')
          end
        end

        it 'returns all claims if params not passed' do
          VCR.use_cassette('travel_pay/200_claims', match_requests_on: %i[method path]) do
            get '/travel_pay/v0/claims', params: nil, headers: { 'Authorization' => 'Bearer vagov_token' }
            expect(response).to have_http_status(:ok)
            claim_ids = JSON.parse(response.body)['data'].pluck('id')
            expect(claim_ids.length).to eq(3)
          end
        end

        it 'responds with a 404 if the API endpoint is not found' do
          VCR.use_cassette('travel_pay/404_claims', match_requests_on: %i[method path]) do
            get '/travel_pay/v0/claims', params: nil, headers: { 'Authorization' => 'Bearer vagov_token' }
            expect(response).to have_http_status(:bad_request)
          end
        end
      end
    end
  end

  describe '#show' do
    before do
      Flipper.enable(:travel_pay_view_claim_details)
    end

    it 'returns a single claim on success' do
      VCR.use_cassette('travel_pay/show/success', match_requests_on: %i[method path]) do
        # This claim ID matches a claim ID in the cassette.
        claim_id = '33016896-ed7f-4d4f-a81b-cc4f2ca0832c'
        expected_claim_num = 'TC092809828275'

        get "/travel_pay/v0/claims/#{claim_id}", headers: { 'Authorization' => 'Bearer vagov_token' }
        actual_claim_num = JSON.parse(response.body)['claimNumber']

        expect(response).to have_http_status(:ok)
        expect(actual_claim_num).to eq(expected_claim_num)
      end
    end

    it 'returns a Not Found response if claim number valid but claim not found' do
      VCR.use_cassette('travel_pay/show/success', match_requests_on: %i[method path]) do
        # This claim ID matches a claim ID in the cassette.
        claim_id = SecureRandom.uuid

        get "/travel_pay/v0/claims/#{claim_id}", headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:not_found)
      end
    end

    it 'returns a ServiceUnavailable response if feature flag turned off' do
      Flipper.disable(:travel_pay_view_claim_details)

      get '/travel_pay/v0/claims/123', headers: { 'Authorization' => 'Bearer vagov_token' }

      expect(response).to have_http_status(:service_unavailable)
    end
  end

  describe '#create' do
    before do
      Flipper.enable(:travel_pay_submit_mileage_expense)
    end
    
    it 'returns a ServiceUnavailable response if feature flag turned off' do
      Flipper.disable(:travel_pay_submit_mileage_expense)

      headers = { 'Authorization' => 'Bearer vagov_token' }
      params = {}

      post '/travel_pay/v0/claims', headers: headers, params: params

      expect(response).to have_http_status(:service_unavailable)
    end
  end
end
