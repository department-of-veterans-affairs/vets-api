# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::TravelPayClaims', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user }

  describe '#create' do
    before do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_submit_mileage_expense, instance_of(User)).and_return(true)
    end

    it 'returns a successfully submitted claim response' do
      allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
        .and_return({ veis_token: 'vt', btsss_token: 'bt' })

      VCR.use_cassette('travel_pay/submit/success', match_requests_on: %i[method path]) do
        params = { 'appointment_date_time' => '2024-01-01T16:45:34.465',
                   'facility_station_number' => '123',
                   'appointment_type' => 'Other',
                   'is_complete' => false }

        post('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)
        expect(response.body).to match_json_schema('travel_pay_smoc_response')
        expect(response).to have_http_status(:created)
      end
    end

    it 'returns a BadRequest response if an invalid appointment date time is given' do
      allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
        .and_return({ veis_token: 'vt', btsss_token: 'bt' })

      VCR.use_cassette('travel_pay/submit/success', match_requests_on: %i[method path], allow_playback_repeats: true) do
        params = { 'appointment_date_time' => 'My birthday, 4 years ago',
                   'facility_station_number' => '123',
                   'appointment_type' => 'Other',
                   'is_complete' => false }

        post('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

        expect(response).to have_http_status(:bad_request)
      end
    end

    it 'returns a server error response if a request to the Travel Pay API fails' do
      allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
        .and_return({ veis_token: 'vt', btsss_token: 'bt' })
      allow_any_instance_of(TravelPay::ClaimsService).to receive(:submit_claim)
        .and_raise(Common::Exceptions::InternalServerError.new(Faraday::ServerError.new))

      # The cassette doesn't matter here as I'm mocking the submit_claim method
      VCR.use_cassette('travel_pay/submit/success', match_requests_on: %i[method path], allow_playback_repeats: true) do
        params = { 'appointment_date_time' => '2024-01-01T16:45:34.465',
                   'facility_station_number' => '123',
                   'appointment_type' => 'Other',
                   'is_complete' => false }

        post('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
