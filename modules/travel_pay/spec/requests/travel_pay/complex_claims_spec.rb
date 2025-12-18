# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::V0::ComplexClaimsController, type: :request do
  let(:user) { build(:user) }
  let(:params) do
    {
      'appointment_date_time' => '2024-01-01T16:45:34.465Z',
      'facility_station_number' => '983',
      'appointment_type' => 'Other',
      'is_complete' => false
    }
  end
  let(:appointment_id) { 'aa0f63e0-5fa7-4d74-a17a-a6f510dbf69e' }
  let(:claim_id) { '3fa85f64-5717-4562-b3fc-2c963f66afa6' }

  before do
    allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize).and_return({ veis_token: 'veis_token',
                                                                                      btsss_token: 'btsss_token' })
    sign_in(user)
    allow_any_instance_of(TravelPay::V0::ComplexClaimsController).to receive(:current_user).and_return(user)
  end

  # POST /travel_pay/v0/complex_claims/
  describe '#create' do
    context 'when travel_pay_enable_complex_claims feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_complex_claims, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:travel_pay_appt_add_v4_upgrade, instance_of(User)).and_return(false)
      end

      context 'VCR-backed integration tests' do
        it 'creates a complex claim and returns claimId using vcr_cassette' do
          VCR.use_cassette('travel_pay/submit/200_find_or_create_appt', match_requests_on: %i[method path]) do
            VCR.use_cassette('travel_pay/submit/200_create_claim', match_requests_on: %i[method path]) do
              post('/travel_pay/v0/complex_claims', params:, as: :json)

              expect(response).to have_http_status(:created)
              expect(JSON.parse(response.body)['claimId']).to eq(claim_id)
            end
          end
        end

        it 'returns a BadRequest response if an invalid appointment date time is given' do
          VCR.use_cassette('travel_pay/submit/200_find_or_create_appt', match_requests_on: %i[method path]) do
            VCR.use_cassette('travel_pay/submit/200_create_claim', match_requests_on: %i[method path]) do
              bad_params = {
                'appointment_date_time' => 'My birthday, 4 years ago',
                'facility_station_number' => '123',
                'appointment_type' => 'Other',
                'is_complete' => false
              }
              post('/travel_pay/v0/complex_claims', params: bad_params, as: :json)

              expect(response).to have_http_status(:bad_request)
              expect(JSON.parse(response.body)['errors'].first['detail'])
                .to eq('Appointment date time must be a valid datetime')
            end
          end
        end
      end

      context 'stubbed controller behavior' do
        context 'when claim and appointment services dont error' do
          before do
            # Stub the appointment service
            appts_service_double = instance_double(TravelPay::AppointmentsService)
            allow(appts_service_double).to receive(:find_or_create_appointment)
              .with(hash_including('appointment_date_time' => params['appointment_date_time']))
              .and_return({ data: { 'id' => appointment_id } })
            # Stub the claims service
            claims_service_double = instance_double(TravelPay::ClaimsService)
            allow(claims_service_double).to receive(:create_new_claim)
              .with({ 'btsss_appt_id' => appointment_id })
              .and_return({ 'claimId' => claim_id })
            # Inject stubs into controller
            allow_any_instance_of(TravelPay::V0::ComplexClaimsController)
              .to receive(:appts_service).and_return(appts_service_double)
            allow_any_instance_of(TravelPay::V0::ComplexClaimsController)
              .to receive(:claims_service).and_return(claims_service_double)
          end

          it 'successfully creates complex claim and returns claimId' do
            post('/travel_pay/v0/complex_claims', params:)

            expect(response).to have_http_status(:created)
            expect(JSON.parse(response.body)).to eq('claimId' => claim_id)
          end

          context 'when params are missing' do
            let(:missing_params) do
              {
                'appointment_date_time' => '2024-01-01T16:45:34.465Z',
                'appointment_type' => 'Other',
                'is_complete' => false
              }
            end

            it 'returns bad request when a param is missing' do
              post('/travel_pay/v0/complex_claims', params: missing_params, as: :json)

              expect(response).to have_http_status(:bad_request)
              body = JSON.parse(response.body)
              expect(body['errors'].first['detail'])
                .to eq('The required parameter "facility_station_number", is missing')
            end

            it 'returns bad request when all required params are missing' do
              post('/travel_pay/v0/complex_claims', params: { complex_claim: {} }, as: :json)

              expect(response).to have_http_status(:bad_request)
              body = JSON.parse(response.body)
              expect(body['errors'].first['detail'])
                .to eq('The required parameter "appointment_date_time", is missing')
            end
          end
        end

        context 'when appointment service errors' do
          before do
            # Stub the appointment service to return nil
            allow_any_instance_of(TravelPay::V0::ComplexClaimsController)
              .to receive(:appts_service)
              .and_return(double(find_or_create_appointment: nil))
          end

          it 'returns resource not found when appointment does not exist' do
            post('/travel_pay/v0/complex_claims', params:)

            expect(response).to have_http_status(:not_found)
            expect(JSON.parse(response.body)['error']).to match(/Resource not found/)
          end
        end

        context 'when claims service errors with a Faraday::Error' do
          before do
            # Stub the appointment service
            appts_service_double = instance_double(TravelPay::AppointmentsService)
            allow(appts_service_double).to receive(:find_or_create_appointment)
              .with(hash_including('appointment_date_time' => params['appointment_date_time']))
              .and_return({ data: { 'id' => appointment_id } })
            # Stub the claims service to return a Faraday error
            claims_service_double = instance_double(TravelPay::ClaimsService)
            faraday_error = Faraday::ServerError.new('502 Bad Gateway')
            allow(faraday_error).to receive(:response).and_return({ status: 502 })
            allow(claims_service_double).to receive(:create_new_claim).and_raise(faraday_error)
            # Inject stubs into controller
            allow_any_instance_of(TravelPay::V0::ComplexClaimsController)
              .to receive(:appts_service).and_return(appts_service_double)
            allow_any_instance_of(TravelPay::V0::ComplexClaimsController)
              .to receive(:claims_service).and_return(claims_service_double)
          end

          it 'returns a 500 error with generic error message' do
            post('/travel_pay/v0/complex_claims', params:)

            expect(response).to have_http_status(:bad_gateway)
            body = JSON.parse(response.body)
            expect(body['error']).to eq('Error creating complex claim')
          end
        end
      end
    end

    context 'when feature flag disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:travel_pay_enable_complex_claims, instance_of(User))
          .and_return(false)
      end

      it 'returns 503 Service Unavailable' do
        post('/travel_pay/v0/complex_claims', params: {})

        expect(response).to have_http_status(:service_unavailable)
        body = JSON.parse(response.body)
        expect(body['errors'].first['detail'])
          .to include('Travel Pay complex claim endpoint unavailable per feature toggle')
      end
    end
  end

  # PATCH /travel_pay/v0/complex_claims/#{claim_id}/submit
  describe '#submit' do
    let(:claims_service) { instance_double(TravelPay::ClaimsService) }

    context 'when feature flag enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_complex_claims, instance_of(User)).and_return(true)
      end

      context 'VCR-backed integration tests' do
        it 'submits a complex claim and returns claimId using vcr_cassette' do
          VCR.use_cassette('travel_pay/submit/200_submit_claim', match_requests_on: %i[method path]) do
            patch("/travel_pay/v0/complex_claims/#{claim_id}/submit")

            expect(response).to have_http_status(:created)
            expect(JSON.parse(response.body)['claimId']).to eq(claim_id)
          end
        end

        it 'returns a server error response if a request to the Travel Pay API fails' do
          allow_any_instance_of(TravelPay::ClaimsService).to receive(:submit_claim)
            .and_raise(Faraday::ServerError.new('500 Internal Server Error'))
          VCR.use_cassette('travel_pay/submit/500_submit_claim', match_requests_on: %i[method path]) do
            patch("/travel_pay/v0/complex_claims/#{claim_id}/submit")

            expect(response).to have_http_status(:internal_server_error)
          end
        end
      end

      context 'stubbed service behavior' do
        before do
          allow_any_instance_of(TravelPay::V0::ComplexClaimsController)
            .to receive(:claims_service).and_return(claims_service)
        end

        context 'when there are no service errors' do
          before do
            allow(claims_service).to receive(:submit_claim)
              .with(claim_id)
              .and_return({ 'claimId' => claim_id })
          end

          it 'successfully creates complex claim and returns claimId' do
            patch("/travel_pay/v0/complex_claims/#{claim_id}/submit")

            expect(response).to have_http_status(:created)
            expect(JSON.parse(response.body)).to eq('claimId' => claim_id)
          end

          # NOTE: In request specs, you can’t make params[:claim_id] truly missing because
          # it’s part of the URL path and Rails routing prevents that.
          it 'returns bad request when claim_id is invalid' do
            invalid_claim_id = 'invalid$' # safe in URL, fails regex \A[\w-]+\z

            patch("/travel_pay/v0/complex_claims/#{invalid_claim_id}/submit")

            expect(response).to have_http_status(:bad_request)
            body = JSON.parse(response.body)
            expect(body['errors'].first['detail']).to eq('Claim ID is invalid')
          end
        end

        context 'when there are errors' do
          it 'falls back to :internal_server_error - 500, when Faraday::Error and response is nil' do
            error = Faraday::ConnectionFailed.new('Failed to open TCP connection')
            allow(claims_service).to receive(:submit_claim).with(claim_id).and_raise(error)

            patch("/travel_pay/v0/complex_claims/#{claim_id}/submit")
            expect(response).to have_http_status(:internal_server_error)
            body = JSON.parse(response.body)
            expect(body['errors'].first['detail']).to eq('Error creating complex claim')
          end

          context 'when claims service raises Faraday::ClientError' do
            # This simulates a rare edge case where a Faraday::ClientError is raised
            # without a response object (e.response is nil). Normally Faraday provides
            # a response, but we test this fallback path to ensure the controller still
            # returns a structured 400 Bad Request error.
            it 'falls back to :bad_request - 400 error, when response is nil' do
              error = Faraday::ClientError.new('Connection failed', nil)
              allow(claims_service).to receive(:submit_claim).with(claim_id).and_raise(error)

              patch("/travel_pay/v0/complex_claims/#{claim_id}/submit")

              expect(response).to have_http_status(:bad_request)
              body = JSON.parse(response.body)
              expect(body['errors'].first['detail']).to eq('Invalid request for complex claim')
            end

            it 'uses status from Faraday response and shows default message when is blank' do
              error = Faraday::ClientError.new('Connection failed', { status: 404, body: '' })
              allow(claims_service).to receive(:submit_claim).with(claim_id).and_raise(error)

              patch("/travel_pay/v0/complex_claims/#{claim_id}/submit")

              expect(response).to have_http_status(:not_found)
              body = JSON.parse(response.body)
              expect(body['errors'].first['detail']).to eq('Invalid request for complex claim')
            end

            it 'uses status from Faraday response if present (e.g. 404)' do
              error = Faraday::ClientError.new('404 Not Found', { status: 404, body: 'Claim not found' })
              allow(claims_service).to receive(:submit_claim).with(claim_id).and_raise(error)

              patch("/travel_pay/v0/complex_claims/#{claim_id}/submit")

              expect(response).to have_http_status(:not_found)
              body = JSON.parse(response.body)
              expect(body['errors'].first['detail']).to eq('Claim not found')
            end
          end

          context 'when claims service raises ServerError' do
            # This simulates a rare edge case where a Faraday::ServerError is raised
            # without a response object (e.response is nil). Normally Faraday includes
            # a response with a status code, but this ensures we gracefully fall back
            # to returning a 500 Internal Server Error with a consistent error payload.
            it 'falls back to :internal_server_error - 500, when response is nil' do
              error = Faraday::ServerError.new('Service unavailable', nil)
              allow(claims_service).to receive(:submit_claim).with(claim_id).and_raise(error)

              patch("/travel_pay/v0/complex_claims/#{claim_id}/submit")

              expect(response).to have_http_status(:internal_server_error)
              body = JSON.parse(response.body)
              expect(body['errors'].first['detail']).to eq('Server error submitting complex claim')
            end

            it 'uses status from Faraday response and shows default message when body is blank' do
              error = Faraday::ServerError.new('Service Unavailable', { status: 503, body: '' })
              allow(claims_service).to receive(:submit_claim).with(claim_id).and_raise(error)

              patch("/travel_pay/v0/complex_claims/#{claim_id}/submit")

              expect(response).to have_http_status(:service_unavailable)
              body = JSON.parse(response.body)
              expect(body['errors'].first['detail']).to eq('Server error submitting complex claim')
            end

            it 'uses status from Faraday response if present (e.g. 503)' do
              error = Faraday::ClientError.new(
                'Service Unavailable',
                { status: 503, body: 'TravelPay service is temporarily unavailable' }
              )
              allow(claims_service).to receive(:submit_claim).with(claim_id).and_raise(error)

              patch("/travel_pay/v0/complex_claims/#{claim_id}/submit")

              expect(response).to have_http_status(:service_unavailable)
              body = JSON.parse(response.body)
              expect(body['errors'].first['detail']).to eq('TravelPay service is temporarily unavailable')
            end
          end
        end
      end
    end

    context 'when feature flag disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:travel_pay_enable_complex_claims, instance_of(User))
          .and_return(false)
      end

      it 'returns 503 Service Unavailable' do
        patch("/travel_pay/v0/complex_claims/#{claim_id}/submit", params: {})

        expect(response).to have_http_status(:service_unavailable)
        body = JSON.parse(response.body)
        expect(body['errors'].first['detail'])
          .to include('Travel Pay complex claim endpoint unavailable per feature toggle')
      end
    end
  end

  describe 'endpoint version routing' do
    before do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_complex_claims, instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_appt_add_v4_upgrade, instance_of(User)).and_return(false)
    end

    context 'when travel_pay_claims_api_v3_upgrade is enabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:travel_pay_claims_api_v3_upgrade)
          .and_return(true)
      end

      it 'uses v3 endpoint for create_claim' do
        VCR.use_cassette('travel_pay/submit/200_find_or_create_appt', match_requests_on: %i[method path]) do
          VCR.use_cassette('travel_pay/claims_v3/200_create_claim', match_requests_on: %i[method path]) do
            post('/travel_pay/v0/complex_claims', params:, as: :json)

            expect(response).to have_http_status(:created)
            expect(JSON.parse(response.body)['claimId']).to eq(claim_id)
          end
        end
      end

      it 'uses v3 endpoint for submit_claim' do
        VCR.use_cassette('travel_pay/claims_v3/200_submit_claim', match_requests_on: %i[method path]) do
          patch("/travel_pay/v0/complex_claims/#{claim_id}/submit")

          expect(response).to have_http_status(:created)
          expect(JSON.parse(response.body)['claimId']).to eq(claim_id)
        end
      end
    end

    context 'when travel_pay_claims_api_v3_upgrade is disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:travel_pay_claims_api_v3_upgrade)
          .and_return(false)
      end

      it 'uses v2 endpoint for create_claim' do
        VCR.use_cassette('travel_pay/submit/200_find_or_create_appt', match_requests_on: %i[method path]) do
          VCR.use_cassette('travel_pay/submit/200_create_claim', match_requests_on: %i[method path]) do
            post('/travel_pay/v0/complex_claims', params:, as: :json)

            expect(response).to have_http_status(:created)
            expect(JSON.parse(response.body)['claimId']).to eq(claim_id)
          end
        end
      end

      it 'uses v2 endpoint for submit_claim' do
        VCR.use_cassette('travel_pay/submit/200_submit_claim', match_requests_on: %i[method path]) do
          patch("/travel_pay/v0/complex_claims/#{claim_id}/submit")

          expect(response).to have_http_status(:created)
          expect(JSON.parse(response.body)['claimId']).to eq(claim_id)
        end
      end
    end
  end
end
