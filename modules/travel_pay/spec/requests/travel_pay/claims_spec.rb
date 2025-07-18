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

      let(:tokens) do
        { veis_token: 'veis_token', btsss_token: 'btsss_token' }
      end

      it 'responds with 200 when no params passed in' do
        VCR.use_cassette('travel_pay/200_search_claims_by_appt_date_range', match_requests_on: %i[method path]) do
          get '/travel_pay/v0/claims', params: nil, headers: { 'Authorization' => 'Bearer vagov_token' }
          expect(response).to have_http_status(:ok)
          claim_ids = JSON.parse(response.body)['data'].pluck('id')
          claim_meta = JSON.parse(response.body)['metadata']
          expect(claim_meta['totalRecordCount']).to eq(3)

          expect(claim_ids).to eq(expected_claim_ids)
        end
      end

      it 'responds with 200 when page size or page number is passed in' do
        params = { 'start_date' => '2025-01-01T00.00.00Z', 'end_date' => '2025-03-01T00.00.00Z' }

        VCR.use_cassette('travel_pay/200_search_claims_by_appt_date_range', match_requests_on: %i[method path]) do
          get '/travel_pay/v0/claims', params:, headers: { 'Authorization' => 'Bearer vagov_token' }
          expect(response).to have_http_status(:ok)
          claim_ids = JSON.parse(response.body)['data'].pluck('id')
          claim_meta = JSON.parse(response.body)['metadata']

          expect(claim_meta['totalRecordCount']).to eq(3)

          expect(claim_ids).to eq(expected_claim_ids)
        end
      end

      # 206_search_claims_partial_response
      it 'responds with 206 when part of the claim retrieval fails' do
        params = { 'start_date' => '2025-01-01T00.00.00Z', 'end_date' => '2025-03-01T00.00.00Z' }

        VCR.use_cassette('travel_pay/206_search_claims_partial_response', match_requests_on: %i[method path]) do
          get '/travel_pay/v0/claims', params:, headers: { 'Authorization' => 'Bearer vagov_token' }
          expect(response).to have_http_status(:partial_content)
          claim_ids = JSON.parse(response.body)['data'].pluck('id')
          claim_meta = JSON.parse(response.body)['metadata']

          expect(claim_meta['totalRecordCount']).to eq(3)
          expect(claim_meta['pageNumber']).to eq(2)
          expect(claim_meta['status']).to eq(206)

          expect(claim_ids.size).to eq(2)
        end
      end
    end
  end

  describe '#show' do
    before do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_power_switch, instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_claims_management, instance_of(User)).and_return(false)
    end

    it 'returns expanded claim details on success' do
      VCR.use_cassette('travel_pay/show/success_details', match_requests_on: %i[method path]) do
        claim_id = '3fa85f64-5717-4562-b3fc-2c963f66afa6'
        expected_claim_num = 'TC0000000000001'

        get "/travel_pay/v0/claims/#{claim_id}", headers: { 'Authorization' => 'Bearer vagov_token' }
        actual_claim_num = JSON.parse(response.body)['claimNumber']
        documents_array = JSON.parse(response.body)['documents']

        expect(response).to have_http_status(:ok)
        expect(documents_array).to be_empty
        expect(actual_claim_num).to eq(expected_claim_num)
      end
    end

    # Should be a 404 but for now a 400
    it 'returns a Not Found response if claim ID valid but claim not found' do
      VCR.use_cassette('travel_pay/404_claim_details', match_requests_on: %i[method path]) do
        claim_id = 'aa0f63e0-5fa7-4d74-a17a-a6f510dbf69e'

        get "/travel_pay/v0/claims/#{claim_id}", headers: { 'Authorization' => 'Bearer vagov_token' }
        expect(response).to have_http_status(:bad_request)
      end
    end

    it 'appends document information if claims management flipper is on' do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_power_switch, instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_claims_management, instance_of(User)).and_return(true)

      VCR.use_cassette('travel_pay/show/success_details', match_requests_on: %i[method path]) do
        claim_id = '3fa85f64-5717-4562-b3fc-2c963f66afa6'

        get "/travel_pay/v0/claims/#{claim_id}", headers: { 'Authorization' => 'Bearer vagov_token' }
        documents_array = JSON.parse(response.body)['documents']
        expect(response).to have_http_status(:ok)
        expect(documents_array).not_to be_empty
      end
    end

    it 'returns a ServiceUnavailable response if feature flag turned off' do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_power_switch, instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_claims_management, instance_of(User)).and_return(false)

      get '/travel_pay/v0/claims/123', headers: { 'Authorization' => 'Bearer vagov_token' }
      expect(response).to have_http_status(:service_unavailable)
    end
  end

  describe '#create' do
    before do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_submit_mileage_expense, instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_power_switch, instance_of(User)).and_return(true)
    end

    it 'returns a ServiceUnavailable response if feature flag turned off' do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_submit_mileage_expense, instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_power_switch, instance_of(User)).and_return(true)

      headers = { 'Authorization' => 'Bearer vagov_token' }
      params = {}

      post('/travel_pay/v0/claims', headers:, params:)

      expect(response).to have_http_status(:service_unavailable)
    end

    it 'returns a successfully submitted claim response' do
      allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
        .and_return({ veis_token: 'vt', btsss_token: 'bt' })

      VCR.use_cassette('travel_pay/submit/success', match_requests_on: %i[method path]) do
        headers = { 'Authorization' => 'Bearer vagov_token' }
        params = { 'appointment_date_time' => '2024-01-01T16:45:34.465Z',
                   'facility_station_number' => '123',
                   'appointment_type' => 'Other',
                   'is_complete' => false }

        post('/travel_pay/v0/claims', headers:, params:)
        expect(response).to have_http_status(:created)
      end
    end

    it 'returns a BadRequest response if an invalid appointment date time is given' do
      allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
        .and_return({ veis_token: 'vt', btsss_token: 'bt' })

      VCR.use_cassette('travel_pay/submit/success', match_requests_on: %i[method path]) do
        headers = { 'Authorization' => 'Bearer vagov_token' }
        params = { 'appointment_date_time' => 'My birthday, 4 years ago',
                   'facility_station_number' => '123',
                   'appointment_type' => 'Other',
                   'is_complete' => false }

        post('/travel_pay/v0/claims', headers:, params:)

        expect(response).to have_http_status(:bad_request)
      end
    end

    it 'returns a server error response if a request to the Travel Pay API fails' do
      allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
        .and_return({ veis_token: 'vt', btsss_token: 'bt' })
      allow_any_instance_of(TravelPay::ClaimsService).to receive(:submit_claim)
        .and_raise(Common::Exceptions::InternalServerError.new(Faraday::ServerError.new))

      # The cassette doesn't matter here as I'm mocking the submit_claim method
      VCR.use_cassette('travel_pay/submit/success', match_requests_on: %i[method path]) do
        headers = { 'Authorization' => 'Bearer vagov_token' }
        params = { 'appointment_date_time' => '2024-01-01T16:45:34.465Z',
                   'facility_station_number' => '123',
                   'appointment_type' => 'Other',
                   'is_complete' => false }

        post('/travel_pay/v0/claims', headers:, params:)

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
