# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::V0::ComplexClaimsController, type: :request do
  let(:user) { build(:user) }

  before do
    sign_in(user)
  end

  describe '#create' do
    before do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_complex_claims, instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_power_switch, instance_of(User)).and_return(true)
    end

    it 'returns a ServiceUnavailable response if feature flag turned off' do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_complex_claims, instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_power_switch, instance_of(User)).and_return(true)

      headers = { 'Authorization' => 'Bearer vagov_token' }
      params = {}

      post('/travel_pay/v0/complex_claims', headers:, params:)

      expect(response).to have_http_status(:service_unavailable)
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:travel_pay_complex_claims, instance_of(User)).and_return(true)
      end

      let(:headers) { { 'Authorization' => 'Bearer vagov_token', 'Content-Type' => 'application/json' } }
      let(:appointment_date_time) { Time.now.utc.iso8601 }
      let(:params) { { appointment_date_time: }.to_json }

      it 'creates a complex claim and returns 201' do
        VCR.use_cassette('travel_pay/complex_claims/create_success') do
          post('/travel_pay/v0/complex_claims', headers:, params:)

          expect(response).to have_http_status(:created)
          expect(response.content_type).to eq('application/json; charset=utf-8')
          expect(JSON.parse(response.body['data'])).to include('claimId')
        end
      end

      it 'returns 500 if the Travel Pay API fails' do
        allow(TravelPay::ClaimService).to receive(:create).and_raise(StandardError.new('API failure'))

        expect(Rails.logger).to receive(:error).with(/API failure/)

        post('/travel_pay/v0/complex_claims', headers:, params:)

        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)).to include('errors')
      end

      it 'returns 422 if appointment_date_time is missing' do
        expect(TravelPay::ClaimService).not_to receive(:create)

        post('/travel_pay/v0/complex_claims', headers:, params: {}.to_json)

        expect(Rails.logger).to receive(:error).with(/missing date time/i)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to include('errors')
      end

      it 'returns 422 if appointment_date_time is not a valid datetime' do
        # Validations expected to happen before hitting Travel Pay API
        # So we expect the service not to be called
        expect(TravelPay::ClaimService).not_to receive(:create)

        post('/travel_pay/v0/complex_claims', headers:, params: { appointment_date_time: 'not-a-date' }.to_json)

        expect(Rails.logger).to receive(:error).with(/invalid date time/i)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to include('errors')
      end
    end
  end
end
