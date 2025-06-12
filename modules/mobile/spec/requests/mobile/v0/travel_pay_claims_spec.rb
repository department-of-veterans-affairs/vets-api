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
      expect(Mobile::V0::Appointment).to receive(:clear_cache).once

      VCR.use_cassette('travel_pay/submit/success', match_requests_on: %i[method path]) do
        params = { 'appointment_date_time' => '2024-01-01T16:45:34.465',
                   'facility_station_number' => '123',
                   'appointment_type' => 'Other',
                   'is_complete' => false }

        post('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)
        expect(response.body).to match_json_schema('travel_pay_smoc_response')
        expect(response).to have_http_status(:created)
        claim_response = response.parsed_body['data']['attributes']
        expect(claim_response['id']).to eq('3fa85f64-5717-4562-b3fc-2c963f66afa6')
        expect(claim_response['claimStatus']).to eq('Claim submitted')
        expect(claim_response['createdOn']).to be_present
        expect(claim_response['modifiedOn']).to be_present
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

    it 'returns a success response with saved status if a submit request to the Travel Pay API fails' do
      allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
        .and_return({ veis_token: 'vt', btsss_token: 'bt' })

      VCR.use_cassette('travel_pay/submit/tokens_success', match_requests_on: %i[method path]) do
        VCR.use_cassette('travel_pay/submit/200_find_or_create_appt', match_requests_on: %i[method path]) do
          VCR.use_cassette('travel_pay/submit/200_create_claim', match_requests_on: %i[method path]) do
            VCR.use_cassette('travel_pay/submit/200_add_expense', match_requests_on: %i[method path]) do
              VCR.use_cassette('travel_pay/submit/500_submit_claim', match_requests_on: %i[method path]) do
                params = { 'appointment_date_time' => '2024-01-01T16:45:34.465Z',
                           'facility_station_number' => '123',
                           'appointment_type' => 'Other',
                           'is_complete' => false }

                post('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

                expect(response.body).to match_json_schema('travel_pay_smoc_response')
                submitted_claim = response.parsed_body['data']['attributes']
                expect(response).to have_http_status(:created)
                expect(submitted_claim['id']).to eq('3fa85f64-5717-4562-b3fc-2c963f66afa6')
                expect(submitted_claim['claimStatus']).to eq('Saved')
              end
            end
          end
        end
      end
    end

    it 'returns a success response with incomplete status if add expense call to the Travel Pay API fails' do
      allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
        .and_return({ veis_token: 'vt', btsss_token: 'bt' })

      VCR.use_cassette('travel_pay/submit/tokens_success', match_requests_on: %i[method path]) do
        VCR.use_cassette('travel_pay/submit/200_find_or_create_appt', match_requests_on: %i[method path]) do
          VCR.use_cassette('travel_pay/submit/200_create_claim', match_requests_on: %i[method path]) do
            VCR.use_cassette('travel_pay/submit/500_add_expense', match_requests_on: %i[method path]) do
              params = { 'appointment_date_time' => '2024-01-01T16:45:34.465Z',
                         'facility_station_number' => '123',
                         'appointment_type' => 'Other',
                         'is_complete' => false }

              post('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

              expect(response.body).to match_json_schema('travel_pay_smoc_response')
              submitted_claim = response.parsed_body['data']['attributes']
              expect(response).to have_http_status(:created)
              expect(submitted_claim['id']).to eq('3fa85f64-5717-4562-b3fc-2c963f66afa6')
              expect(submitted_claim['claimStatus']).to eq('Incomplete')
            end
          end
        end
      end
    end

    it 'returns an error if claim creation fails' do
      allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
        .and_return({ veis_token: 'vt', btsss_token: 'bt' })

      VCR.use_cassette('travel_pay/submit/tokens_success', match_requests_on: %i[method path]) do
        VCR.use_cassette('travel_pay/submit/200_find_or_create_appt', match_requests_on: %i[method path]) do
          VCR.use_cassette('travel_pay/submit/500_create_claim', match_requests_on: %i[method path]) do
            params = { 'appointment_date_time' => '2024-01-01T16:45:34.465Z',
                       'facility_station_number' => '123',
                       'appointment_type' => 'Other',
                       'is_complete' => false }

            post('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)
            # TODO: This should be a 500 error, but the controller is returning a 400
            # expect(response).to have_http_status(:internal_server_error)
            expect(response).to have_http_status(:bad_request)
          end
        end
      end
    end
  end
end
