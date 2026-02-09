# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Vass::V0::Appointments - Cancel Appointment', type: :request do
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:veteran_id) { 'vet-uuid-123' }
  let(:edipi) { '1234567890' }
  let(:jwt_secret) { 'test-jwt-secret' }
  let(:appointment_id) { 'e61e1a40-1e63-f011-bec2-001dd80351ea' }
  let(:jti) { SecureRandom.uuid }
  let(:jwt_token) do
    payload = {
      sub: veteran_id,
      exp: 1.hour.from_now.to_i,
      iat: Time.current.to_i,
      jti:
    }
    JWT.encode(payload, jwt_secret, 'HS256')
  end

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear

    # Stub VASS settings
    allow(Settings).to receive(:vass).and_return(
      OpenStruct.new(
        auth_url: 'https://login.microsoftonline.us',
        tenant_id: 'test-tenant-id',
        client_id: 'test-client-id',
        client_secret: 'test-client-secret',
        jwt_secret:,
        scope: 'https://api.va.gov/.default',
        api_url: 'https://api.vass.va.gov',
        subscription_key: 'test-subscription-key',
        service_name: 'vass_api',
        redis_otp_expiry: 600,
        redis_session_expiry: 7200,
        redis_token_expiry: 3540,
        rate_limit_max_attempts: 5,
        rate_limit_expiry: 900
      )
    )

    # Set up session in Redis keyed by UUID (veteran_id) with jti stored in session data
    redis_client = Vass::RedisClient.build
    redis_client.save_session(uuid: veteran_id, jti:, edipi:, veteran_id:)
  end

  describe 'POST /vass/v0/appointment/:appointment_id/cancel' do
    let(:headers) do
      {
        'Authorization' => "Bearer #{jwt_token}",
        'Content-Type' => 'application/json'
      }
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized status' do
        post("/vass/v0/appointment/#{appointment_id}/cancel",
             headers: { 'Content-Type' => 'application/json' })

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end
    end

    context 'when user is authenticated' do
      it 'cancels appointment successfully' do
        VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/appointments/cancel_appointment_success', match_requests_on: %i[method uri]) do
            post("/vass/v0/appointment/#{appointment_id}/cancel", headers:)

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)

            expect(json_response['data']).to be_present
            expect(json_response['data']['appointmentId']).to eq(appointment_id)
          end
        end
      end

      it 'returns appointment ID in response' do
        VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/appointments/cancel_appointment_success', match_requests_on: %i[method uri]) do
            post("/vass/v0/appointment/#{appointment_id}/cancel", headers:)

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)

            expect(json_response['data']['appointmentId']).to be_a(String)
            expect(json_response['data']['appointmentId']).not_to be_empty
          end
        end
      end

      context 'when appointment ID is missing' do
        it 'returns not found' do
          post('/vass/v0/appointment//cancel', headers:)

          expect(response).to have_http_status(:not_found)
        end
      end

      context 'when cancellation fails' do
        it 'returns bad gateway' do
          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/cancel_appointment_failed', match_requests_on: %i[method uri]) do
              post('/vass/v0/appointment/already-cancelled-id/cancel', headers:)

              expect(response).to have_http_status(:bad_gateway)
              json_response = JSON.parse(response.body)

              expect(json_response['errors']).to be_present
              expect(json_response['errors'].first['code']).to eq('vass_api_error')
            end
          end
        end
      end

      context 'when session is missing from Redis (token revoked)' do
        before do
          redis_client = Vass::RedisClient.build
          redis_client.delete_session(uuid: veteran_id)
        end

        it 'returns unauthorized status with revoked token error' do
          post("/vass/v0/appointment/#{appointment_id}/cancel", headers:)

          expect(response).to have_http_status(:unauthorized)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['detail']).to eq('Token is invalid or already revoked')
        end
      end

      context 'when VASS API returns an error' do
        it 'returns bad gateway status' do
          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            allow_any_instance_of(Vass::AppointmentsService).to receive(:cancel_appointment).and_raise(
              Vass::Errors::VassApiError.new('VASS API error')
            )

            post("/vass/v0/appointment/#{appointment_id}/cancel", headers:)

            expect(response).to have_http_status(:bad_gateway)
            json_response = JSON.parse(response.body)
            expect(json_response['errors']).to be_present
            expect(json_response['errors'].first['code']).to eq('vass_api_error')
          end
        end
      end
    end
  end
end
