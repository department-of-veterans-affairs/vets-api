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

  # POST /travel_pay/v0/complex_claims/#{claim_is}/submit
  describe '#submit' do
    let(:claims_service) { instance_double(TravelPay::ClaimsService) }

    context 'when feature flag enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_complex_claims, instance_of(User)).and_return(true)
      end

      context 'VCR-backed integration tests' do
        it 'submits a complex claim and returns claimId using vcr_cassette' do
          VCR.use_cassette('travel_pay/submit/200_submit_claim', match_requests_on: %i[method path]) do
            post("/travel_pay/v0/complex_claims/#{claim_id}/submit")

            expect(response).to have_http_status(:created)
            expect(JSON.parse(response.body)['claimId']).to eq(claim_id)
          end
        end

        it 'returns a server error response if a request to the Travel Pay API fails' do
          allow_any_instance_of(TravelPay::ClaimsService).to receive(:submit_claim)
            .and_raise(Faraday::ServerError.new('500 Internal Server Error'))
          VCR.use_cassette('travel_pay/submit/500_submit_claim', match_requests_on: %i[method path]) do
            post("/travel_pay/v0/complex_claims/#{claim_id}/submit")

            expect(response).to have_http_status(:internal_server_error)
          end
        end
      end

      context 'stubbed service behavior' do
        context 'when there are no service errors' do
          before do
            allow(claims_service).to receive(:submit_claim)
              .with(claim_id)
              .and_return({ 'claimId' => claim_id })
            allow_any_instance_of(TravelPay::V0::ComplexClaimsController)
              .to receive(:claims_service).and_return(claims_service)
          end

          it 'successfully creates complex claim and returns claimId' do
            post("/travel_pay/v0/complex_claims/#{claim_id}/submit")

            expect(response).to have_http_status(:created)
            expect(JSON.parse(response.body)).to eq('claimId' => claim_id)
          end

          # NOTE: In request specs, you can’t make params[:claim_id] truly missing because
          # it’s part of the URL path and Rails routing prevents that.
          it 'returns bad request when claim_id is invalid' do
            invalid_claim_id = 'invalid$' # safe in URL, fails regex \A[\w-]+\z

            post("/travel_pay/v0/complex_claims/#{invalid_claim_id}/submit")

            expect(response).to have_http_status(:bad_request)
            body = JSON.parse(response.body)
            expect(body['errors'].first['detail']).to eq('Claim ID is invalid')
          end
        end

        context 'when there are errors' do
          context 'when claims service raises Faraday::ClientError' do
            before do
              allow(claims_service).to receive(:submit_claim)
                .with(claim_id)
                .and_raise(Faraday::ClientError.new('400 Bad Request'))
              allow_any_instance_of(TravelPay::V0::ComplexClaimsController)
                .to receive(:claims_service).and_return(claims_service)
            end

            it 'returns 500 Internal Server Error' do
              post("/travel_pay/v0/complex_claims/#{claim_id}/submit")
              expect(response).to have_http_status(:internal_server_error)
            end
          end

          context 'when claims service raises ArgumentError' do
            before do
              allow(claims_service).to receive(:submit_claim)
                .with(claim_id)
                .and_raise(ArgumentError.new('Something is wrong'))
              allow_any_instance_of(TravelPay::V0::ComplexClaimsController)
                .to receive(:claims_service).and_return(claims_service)
            end

            it 'returns 400 Bad Request with error detail' do
              post("/travel_pay/v0/complex_claims/#{claim_id}/submit")
              expect(response).to have_http_status(:bad_request)
              expect(JSON.parse(response.body)['errors'].first['detail']).to eq('Something is wrong')
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
        post("/travel_pay/v0/complex_claims/#{claim_id}/submit", params: {})

        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end
end
