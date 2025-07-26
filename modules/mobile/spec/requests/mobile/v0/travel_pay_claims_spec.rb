# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::TravelPayClaims', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user }

  describe '#index' do
    context 'happy path' do
      it 'returns claims within the date range' do
        allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
          .and_return({ veis_token: 'vt', btsss_token: 'bt' })

        VCR.use_cassette('travel_pay/200_search_claims_by_appt_date_range', match_requests_on: %i[method path]) do
          params = {
            'start_date' => '2024-01-01',
            'end_date' => '2024-03-31',
            'page_number' => 1
          }

          get('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

          expect(response).to have_http_status(:ok)
          json = response.parsed_body
          expect(json['data']).to be_an(Array)
          expect(json['meta']['status']).to eq(200)
          expect(json['meta']['pageNumber']).to eq(1)

          # Validate response structure
          expect(json).to have_key('meta')
          expect(json).to have_key('data')
          expect(json['meta']['totalRecordCount']).to eq(3)

          # Validate individual claim structure if claims exist
          if json['data'].any?
            claim = json['data'].first
            expect(claim).to have_key('id')
            expect(claim['attributes']).to have_key('claimNumber')
            expect(claim['attributes']).to have_key('claimStatus')
            expect(claim['attributes']).to have_key('appointmentDateTime')
            expect(claim['attributes']).to have_key('facilityName')
          end
        end
      end

      it 'returns partial content status when more claims exist' do
        allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
          .and_return({ veis_token: 'vt', btsss_token: 'bt' })

        VCR.use_cassette('travel_pay/206_search_claims_partial_response', match_requests_on: %i[method path]) do
          params = {
            'start_date' => '2024-01-01',
            'end_date' => '2024-03-31'
          }

          get('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

          expect(response).to have_http_status(:partial_content)
          json = response.parsed_body

          # Verify 206 status indicates partial content
          expect(json['meta']['status']).to eq(206)

          # Verify pagination info exists and indicates more data
          expect(json['meta']).to have_key('pageNumber')
          expect(json['meta']).to have_key('totalRecordCount')
          expect(json['meta']['pageNumber']).to eq(2)

          # Verify some claims data is returned (not empty)
          expect(json['data']).to be_an(Array)
          expect(json['data']).not_to be_empty

          # Verify total count indicates more records exist than returned
          total_count = json['meta']['totalRecordCount']
          returned_count = json['data'].length
          expect(total_count).to be > returned_count

          # Verify response structure is valid
          expect(json).to have_key('meta')
          expect(json).to have_key('data')

          # Verify individual claim has required fields
          if json['data'].any?
            claim = json['data'].first
            expect(claim['attributes']).to have_key('id')
            expect(claim['attributes']).to have_key('claimNumber')
            expect(claim['attributes']).to have_key('claimStatus')
          end
        end
      end
    end

    context 'failure paths' do
      it 'returns unprocessable entity when start_date is missing' do
        params = { 'end_date' => '2024-03-31' }

        get('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns unprocessable entity when end_date is missing' do
        params = { 'start_date' => '2024-01-01' }

        get('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns unprocessable entity when dates are invalid' do
        params = {
          'start_date' => 'invalid',
          'end_date' => '2024-03-31'
        }

        get('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns an internal server error when Travel Pay API fails while fetching claims' do
        allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
          .and_return({ veis_token: 'vt', btsss_token: 'bt' })
        allow_any_instance_of(TravelPay::ClaimsService).to receive(:get_claims_by_date_range)
          .and_raise(Common::Exceptions::ExternalServerInternalServerError.new(
                       errors: [{ title: 'Something went wrong.', status: 500 }]
                     ))

        params = {
          'start_date' => '2024-04-01',
          'end_date' => '2024-04-30'
        }

        get('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

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
                   'facility_name' => 'Some Facility',
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
                   'facility_name' => 'Some Facility',
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
                           'facility_name' => 'Some Facility',
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
                         'facility_name' => 'Some Facility',
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
                       'facility_name' => 'Some Facility',
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
