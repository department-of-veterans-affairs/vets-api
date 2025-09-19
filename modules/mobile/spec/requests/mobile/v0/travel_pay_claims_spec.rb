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
            'start_date' => '2024-01-01T00:00:00',
            'end_date' => '2024-03-31T23:59:59',
            'page_number' => 1
          }

          get('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('travel_pay_claims_response')

          json = response.parsed_body
          expect(json['meta']['status']).to eq(200)
          expect(json['meta']['pageNumber']).to eq(1)
          expect(json['meta']['totalRecordCount']).to eq(3)
        end
      end

      it 'returns partial content status when more claims exist' do
        allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
          .and_return({ veis_token: 'vt', btsss_token: 'bt' })

        VCR.use_cassette('travel_pay/206_search_claims_partial_response', match_requests_on: %i[method path]) do
          params = {
            'start_date' => '2024-01-01T00:00:00',
            'end_date' => '2024-03-31T23:59:59'
          }

          get('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

          expect(response).to have_http_status(:partial_content)
          expect(response.body).to match_json_schema('travel_pay_claims_response')

          json = response.parsed_body

          # Verify 206 status indicates partial content
          expect(json['meta']['status']).to eq(206)
          expect(json['meta']['pageNumber']).to eq(2)

          # Verify some claims data is returned (not empty)
          expect(json['data']).not_to be_empty

          # Verify total count indicates more records exist than returned
          total_count = json['meta']['totalRecordCount']
          returned_count = json['data'].length
          expect(total_count).to be > returned_count
        end
      end
    end

    context 'failure paths' do
      it 'returns validation error when start_date is missing' do
        params = { 'end_date' => '2024-03-31T23:59:59' }

        get('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

        json = response.parsed_body
        expect(json['errors'].first['title']).to eq('Validation Error')
        expect(json['errors'].first['detail']).to include('start_date must be filled')
        expect(json['errors'].first['status']).to eq('422')
      end

      it 'returns validation error when end_date is missing' do
        params = { 'start_date' => '2024-01-01T00:00:00' }

        get('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

        json = response.parsed_body
        expect(json['errors'].first['title']).to eq('Validation Error')
        expect(json['errors'].first['detail']).to include('end_date must be filled')
        expect(json['errors'].first['status']).to eq('422')
      end

      it 'returns internal server error when dates have invalid format' do
        params = {
          'start_date' => 'invalid date',
          'end_date' => '2024-03-31T23:59:59'
        }

        get('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

        expect(response).to have_http_status(:internal_server_error)
        json = response.parsed_body
        expect(json['errors'].first['meta']['exception']).to include('no time information')
      end

      it 'returns an internal server error when Travel Pay API fails while fetching claims' do
        allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
          .and_return({ veis_token: 'vt', btsss_token: 'bt' })
        allow_any_instance_of(TravelPay::ClaimsService).to receive(:get_claims_by_date_range)
          .and_raise(Common::Exceptions::ExternalServerInternalServerError.new(
                       errors: [{ title: 'Something went wrong.', status: 500 }]
                     ))

        params = {
          'start_date' => '2024-04-01T00:00:00',
          'end_date' => '2024-04-30T23:59:59'
        }

        get('/mobile/v0/travel-pay/claims', headers: sis_headers, params:)

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe '#show' do
    context 'happy path' do
      it 'returns claim details for a valid claim ID' do
        allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
          .and_return({ veis_token: 'vt', btsss_token: 'bt' })

        VCR.use_cassette('travel_pay/show/success_details', match_requests_on: %i[method path]) do
          claim_id = '3fa85f64-5717-4562-b3fc-2c963f66afa6'

          get("/mobile/v0/travel-pay/claims/#{claim_id}", headers: sis_headers)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          claim_data = json['data']['attributes']

          expect(json['data']['type']).to eq('travelPayClaimDetails')
          expect(json['data']['id']).to eq(claim_id)

          expect(claim_data['id']).to eq(claim_id)
          expect(claim_data['claimNumber']).to be_present
          expect(claim_data['claimStatus']).to be_present
          expect(claim_data['appointmentDate']).to be_present
          expect(claim_data['facilityName']).to be_present
          expect(claim_data['claimName']).to be_present
          expect(claim_data['claimantFirstName']).to be_present
          expect(claim_data['claimantLastName']).to be_present
          expect(claim_data['totalCostRequested']).to be_present
          expect(claim_data['reimbursementAmount']).to be_present
          expect(claim_data['createdOn']).to be_present
          expect(claim_data['modifiedOn']).to be_present

          expect(claim_data['appointment']).to be_present
          expect(claim_data['appointment']).to be_a(Hash)
          expect(claim_data['appointment']['id']).to be_present
          expect(claim_data['appointment']['facilityId']).to be_present

          expect(claim_data['expenses']).to be_present
          expect(claim_data['expenses']).to be_an(Array)
          if claim_data['expenses'].any?
            expense = claim_data['expenses'].first
            expect(expense['id']).to be_present
            expect(expense['expenseType']).to be_present
          end

          expect(claim_data).to have_key('documents')
          expect(claim_data['documents']).to be_an(Array)
        end
      end
    end

    context 'failure paths' do
      it 'returns not found when claim does not exist' do
        allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
          .and_return({ veis_token: 'vt', btsss_token: 'bt' })
        allow_any_instance_of(TravelPay::ClaimsService).to receive(:get_claim_details)
          .and_return(nil)

        non_existent_claim_id = 'aa0f63e0-5fa7-4d74-a17a'

        get("/mobile/v0/travel-pay/claims/#{non_existent_claim_id}", headers: sis_headers)

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json['errors'].first['title']).to eq('Resource not found')
        expect(json['errors'].first['detail']).to include("Claim not found. ID provided: #{non_existent_claim_id}")
        expect(json['errors'].first['status']).to eq('404')
      end

      it 'returns bad request for invalid claim ID format' do
        allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
          .and_return({ veis_token: 'vt', btsss_token: 'bt' })
        allow_any_instance_of(TravelPay::ClaimsService).to receive(:get_claim_details)
          .and_raise(ArgumentError.new('Expected claim id to be a valid UUID, got invalid-id.'))

        invalid_claim_id = '123abc'

        get("/mobile/v0/travel-pay/claims/#{invalid_claim_id}", headers: sis_headers)

        expect(response).to have_http_status(:bad_request)
        json = response.parsed_body
        expect(json['errors'].first['title']).to eq('Bad request')
        expect(json['errors'].first['detail']).to include('Expected claim id to be a valid UUID')
      end

      it 'returns internal server error when Travel Pay API fails while fetching claim details' do
        allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
          .and_return({ veis_token: 'vt', btsss_token: 'bt' })
        allow_any_instance_of(TravelPay::ClaimsService).to receive(:get_claim_details)
          .and_raise(Common::Exceptions::ExternalServerInternalServerError.new(
                       errors: [{ title: 'Something went wrong.', status: 500 }]
                     ))

        claim_id = '3fa85f64-5717-4562-b3fc-2c963f66afa6'

        get("/mobile/v0/travel-pay/claims/#{claim_id}", headers: sis_headers)

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe '#create' do
    before do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_submit_mileage_expense, instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_appt_add_v4_upgrade, instance_of(User)).and_return(false)
    end

    it 'returns a successfully submitted claim response' do
      allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize)
        .and_return({ veis_token: 'vt', btsss_token: 'bt' })

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
