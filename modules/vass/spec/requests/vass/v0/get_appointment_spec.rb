# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/vass_settings_helper'

RSpec.describe 'Vass::V0::Appointments - Get Appointment', type: :request do
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
    stub_vass_settings(jwt_secret:)

    # Set up session in Redis keyed by UUID (veteran_id) with jti stored in session data
    redis_client = Vass::RedisClient.build
    redis_client.save_session(uuid: veteran_id, jti:, edipi:, veteran_id:)
  end

  describe 'GET /vass/v0/appointment/:appointment_id' do
    let(:headers) do
      {
        'Authorization' => "Bearer #{jwt_token}",
        'Content-Type' => 'application/json'
      }
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized status' do
        get("/vass/v0/appointment/#{appointment_id}",
            headers: { 'Content-Type' => 'application/json' })

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end
    end

    context 'when user is authenticated' do
      it 'returns appointment details successfully' do
        VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/appointments/get_appointment_success', match_requests_on: %i[method uri]) do
            get("/vass/v0/appointment/#{appointment_id}", headers:)

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)

            expect(json_response['data']).to be_present
            expect(json_response['data']['appointmentId']).to eq(appointment_id)
            expect(json_response['data']['startUtc']).to be_present
            expect(json_response['data']['endUtc']).to be_present
            expect(json_response['data']['agentNickname']).to be_present
            expect(json_response['data']['appointmentStatus']).to be_present
          end
        end
      end

      context 'when appointment ID is missing' do
        it 'returns bad request' do
          get('/vass/v0/appointment/', headers:)

          expect(response).to have_http_status(:not_found)
        end
      end

      context 'when appointment is not found' do
        it 'returns not found status' do
          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/get_appointment_404_not_found',
                             match_requests_on: %i[method uri]) do
              get('/vass/v0/appointment/nonexistent-appointment-id', headers:)

              expect(response).to have_http_status(:not_found)
              json_response = JSON.parse(response.body)

              expect(json_response['errors']).to be_present
              expect(json_response['errors'].first['code']).to eq('appointment_not_found')
              expect(json_response['errors'].first['detail']).to eq('Appointment not found')
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
          get("/vass/v0/appointment/#{appointment_id}", headers:)

          expect(response).to have_http_status(:unauthorized)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['detail']).to eq('Token is invalid or already revoked')
        end
      end

      context 'when VASS API returns an error' do
        it 'returns bad gateway status' do
          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            allow_any_instance_of(Vass::AppointmentsService).to receive(:get_appointment).and_raise(
              Vass::Errors::VassApiError.new('VASS API error')
            )

            get("/vass/v0/appointment/#{appointment_id}", headers:)

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
