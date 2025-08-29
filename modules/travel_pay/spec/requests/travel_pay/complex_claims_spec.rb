# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::V0::ComplexClaimsController, type: :request do
  let(:user) { build(:user) }
  let(:params) do
    {
      'appointment_date_time' => '2024-01-01T16:45:34.465Z',
      'facility_station_number' => '123',
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
    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_complex_claims, instance_of(User)).and_return(true)
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
      end

      context 'stubbed controller behavior' do
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

        it 'creates complex claim and returns claimId' do
          post('/travel_pay/v0/complex_claims', params:)

          expect(response).to have_http_status(:created)
          expect(JSON.parse(response.body)).to eq('claimId' => claim_id)
        end

        context 'when params are missing' do
          it 'returns bad request when all params are missing' do
            post('/travel_pay/v0/complex_claims', params: { complex_claim: {} }, as: :json)

            expect(response).to have_http_status(:bad_request)
            body = JSON.parse(response.body)
            expect(body['errors'].first['detail']).to eq('Appointment date time is required')
          end

          it 'returns bad request when all required params are missing' do
            post('/travel_pay/v0/complex_claims', params: { complex_claim: {} }, as: :json)

            expect(response).to have_http_status(:bad_request)
            body = JSON.parse(response.body)

            expected_errors = [
              'Appointment date time is required',
              'Facility station number is required',
              'Appointment type is required',
              'The Is complete field is required'
            ]
            expect(body['errors'].map { |e| e['detail'] }).to match_array(expected_errors)
          end
        end

        it 'returns error json with original status when BackendServiceException' do
          error = Common::Exceptions::BackendServiceException.new('ERROR')
          allow(error).to receive(:original_status).and_return(503)
          allow(service).to receive(:upload_document).and_raise(error)

          post('/travel_pay/v0/complex_claims', params:)

          expect(response).to have_http_status(:service_unavailable)
          expect(JSON.parse(response.body)['error']).to eq('Error downloading document')
        end

        it 'returns error json with status when Faraday::Error' do
          error = Faraday::Error.new('ERROR')
          allow(error).to receive(:response).and_return({ status: 502 }) # 502 = bad_gateway error
          allow(service).to receive(:upload_document).and_raise(error)

          post("/travel_pay/v0/claims/#{claim_id}/documents", params: { Document: valid_document })

          expect(response).to have_http_status(:bad_gateway)
          expect(JSON.parse(response.body)['error']).to eq('Error downloading document')
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
      end
    end
  end
end
