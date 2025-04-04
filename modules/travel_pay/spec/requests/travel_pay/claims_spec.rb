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
      allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_power_switch, instance_of(User)).and_return(true)
    end

    it 'returns expanded claim details on success' do
      VCR.use_cassette('travel_pay/show/success_details', match_requests_on: %i[method path]) do
        claim_id = '3fa85f64-5717-4562-b3fc-2c963f66afa6'
        expected_claim_num = 'TC0000000000001'

        get "/travel_pay/v0/claims/#{claim_id}", headers: { 'Authorization' => 'Bearer vagov_token' }
        actual_claim_num = JSON.parse(response.body)['claimNumber']

        expect(response).to have_http_status(:ok)
        expect(actual_claim_num).to eq(expected_claim_num)
      end
    end

    it 'returns a Bad Request response if claim ID valid but claim not found' do
      VCR.use_cassette('travel_pay/404_claim_details', match_requests_on: %i[method path]) do
        claim_id = 'aa0f63e0-5fa7-4d74-a17a-a6f510dbf69e'

        get "/travel_pay/v0/claims/#{claim_id}", headers: { 'Authorization' => 'Bearer vagov_token' }

        # TODO: This doesn't seem quite right, but it's what the other 404 test returns
        expect(response).to have_http_status(:bad_request)
      end
    end

    it 'returns a ServiceUnavailable response if feature flag turned off' do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_power_switch, instance_of(User)).and_return(true)

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
        params = { 'appointment_datetime' => '2024-01-01T16:45:34.465Z' }

        post('/travel_pay/v0/claims', headers:, params:)
        expect(response).to have_http_status(:created)
      end
    end

    it 'returns a BadRequest response if an invalid appointment date time is given' do
      allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
        .and_return({ veis_token: 'vt', btsss_token: 'bt' })

      VCR.use_cassette('travel_pay/submit/success', match_requests_on: %i[method path]) do
        headers = { 'Authorization' => 'Bearer vagov_token' }
        params = { 'appointment_datetime' => 'My birthday, 4 years ago' }

        post('/travel_pay/v0/claims', headers:, params:)

        expect(response).to have_http_status(:bad_request)
      end
    end

    it 'returns a NotFound response if an appointment is not found' do
      allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
        .and_return({ veis_token: 'vt', btsss_token: 'bt' })

      VCR.use_cassette('travel_pay/submit/success', match_requests_on: %i[method path]) do
        headers = { 'Authorization' => 'Bearer vagov_token' }
        params = { 'appointment_datetime' => '1970-01-01T00:00:00.000Z' }

        post('/travel_pay/v0/claims', headers:, params:)

        error_detail = JSON.parse(response.body)['errors'][0]['detail']
        expect(response).to have_http_status(:not_found)
        expect(error_detail).to match(/appointment/)
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
        params = { 'appointment_datetime' => '2024-01-01T16:45:34.465Z' }

        post('/travel_pay/v0/claims', headers:, params:)

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
