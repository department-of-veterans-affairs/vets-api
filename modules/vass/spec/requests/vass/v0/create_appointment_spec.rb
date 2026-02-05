# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Vass::V0::Appointments - Create Appointment', type: :request do
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:uuid) { 'da1e1a40-1e63-f011-bec2-001dd80351ea' }
  let(:veteran_id) { 'vet-uuid-123' }
  let(:edipi) { '1234567890' }
  let(:jwt_secret) { 'test-jwt-secret' }
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

  describe 'POST /vass/v0/appointment' do
    let(:headers) do
      {
        'Authorization' => "Bearer #{jwt_token}",
        'Content-Type' => 'application/json'
      }
    end

    let(:appointment_params) do
      {
        topics: %w[67e0bd9f-5e53-f011-bec2-001dd806389e 78f1ce0a-6f64-g122-cfd3-112ee917462f],
        dt_start_utc: '2026-01-10T10:00:00Z',
        dt_end_utc: '2026-01-10T10:30:00Z'
      }
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized status' do
        post '/vass/v0/appointment',
             params: appointment_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end
    end

    context 'when user is authenticated' do
      context 'when request is valid' do
        before do
          # Set up appointment ID in booking session (from availability check)
          redis_client = Vass::RedisClient.build
          redis_client.store_booking_session(
            veteran_id:,
            data: { appointment_id: 'cohort-current-123' }
          )
        end

        it 'creates appointment successfully' do
          allow(StatsD).to receive(:increment).and_call_original

          expect(StatsD).to receive(:increment).with(
            'api.vass.controller.appointments.create.success',
            hash_including(tags: array_including('service:vass', 'endpoint:create'))
          ).and_call_original

          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/save_appointment_success', match_requests_on: %i[method uri]) do
              post('/vass/v0/appointment',
                   params: appointment_params.to_json,
                   headers:)

              expect(response).to have_http_status(:ok)
              json_response = JSON.parse(response.body)

              expect(json_response['data']).to be_present
              expect(json_response['data']['appointmentId']).to eq('e61e1a40-1e63-f011-bec2-001dd80351ea')
            end
          end
        end

        it 'tracks success metrics' do
          allow(StatsD).to receive(:increment).and_call_original

          expect(StatsD).to receive(:increment).with(
            'api.vass.controller.appointments.create.success',
            hash_including(tags: array_including('service:vass', 'endpoint:create'))
          ).and_call_original

          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/save_appointment_success', match_requests_on: %i[method uri]) do
              post('/vass/v0/appointment',
                   params: appointment_params.to_json,
                   headers:)
            end
          end
        end

        it 'returns appointment ID in response' do
          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/save_appointment_success', match_requests_on: %i[method uri]) do
              post('/vass/v0/appointment',
                   params: appointment_params.to_json,
                   headers:)

              expect(response).to have_http_status(:ok)
              json_response = JSON.parse(response.body)

              expect(json_response['data']['appointmentId']).to be_a(String)
              expect(json_response['data']['appointmentId']).not_to be_empty
            end
          end
        end
      end

      context 'when booking session is missing from Redis' do
        it 'returns bad request with descriptive error message' do
          # No booking session setup - redis_client.get_booking_session will return nil
          allow(Rails.logger).to receive(:warn).and_call_original
          expect(Rails.logger).to receive(:warn)
            .with(a_string_including('"service":"vass"', '"action":"missing_booking_session"',
                                     "\"vass_uuid\":\"#{veteran_id}"))
            .and_call_original

          post('/vass/v0/appointment',
               params: appointment_params.to_json,
               headers:)

          expect(response).to have_http_status(:bad_request)
          json_response = JSON.parse(response.body)

          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['code']).to eq('missing_session_data')
          expect(json_response['errors'].first['detail']).to eq(
            'Appointment session not found. Please check availability first.'
          )
        end

        it 'does not call the service when session_data is nil' do
          appointments_service = instance_double(Vass::AppointmentsService)
          allow(Vass::AppointmentsService).to receive(:build).and_return(appointments_service)

          # Should NOT call save_appointment because validation fails first
          expect(appointments_service).not_to receive(:save_appointment)

          post('/vass/v0/appointment',
               params: appointment_params.to_json,
               headers:)

          expect(response).to have_http_status(:bad_request)
        end
      end

      context 'when booking session exists but appointment_id is missing' do
        before do
          # Set up session without appointment_id
          redis_client = Vass::RedisClient.build
          redis_client.store_booking_session(
            veteran_id:,
            data: { some_other_key: 'value' }
          )
        end

        it 'returns bad request error' do
          allow(StatsD).to receive(:increment)

          post('/vass/v0/appointment',
               params: appointment_params.to_json,
               headers:)

          expect(response).to have_http_status(:bad_request)
          json_response = JSON.parse(response.body)

          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['code']).to eq('missing_session_data')
          expect(json_response['errors'].first['detail']).to eq(
            'Appointment session not found. Please check availability first.'
          )

          expect(StatsD).to have_received(:increment).with(
            'api.vass.controller.appointments.create.failure',
            hash_including(tags: array_including('service:vass', 'endpoint:create', 'error_type:missing_session_data'))
          ).at_least(:once)
        end

        it 'tracks failure metrics' do
          allow(StatsD).to receive(:increment)

          post('/vass/v0/appointment',
               params: appointment_params.to_json,
               headers:)

          expect(response).to have_http_status(:bad_request)

          expect(StatsD).to have_received(:increment).with(
            'api.vass.controller.appointments.create.failure',
            hash_including(tags: array_including('service:vass', 'endpoint:create', 'error_type:missing_session_data'))
          ).at_least(:once)
        end
      end

      context 'when topics parameter is missing' do
        let(:invalid_params) do
          appointment_params.except(:topics)
        end

        it 'returns bad request' do
          redis_client = Vass::RedisClient.build
          redis_client.store_booking_session(
            veteran_id:,
            data: { appointment_id: 'cohort-current-123' }
          )

          post('/vass/v0/appointment',
               params: invalid_params.to_json,
               headers:)

          expect(response).to have_http_status(:bad_request)
          json_response = JSON.parse(response.body)

          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['code']).to eq('missing_parameter')
          expect(json_response['errors'].first['detail']).to eq('Required parameter is missing')
        end
      end

      context 'when start time is missing' do
        let(:invalid_params) do
          appointment_params.except(:dt_start_utc)
        end

        it 'returns bad request' do
          redis_client = Vass::RedisClient.build
          redis_client.store_booking_session(
            veteran_id:,
            data: { appointment_id: 'cohort-current-123' }
          )

          post('/vass/v0/appointment',
               params: invalid_params.to_json,
               headers:)

          expect(response).to have_http_status(:bad_request)
          json_response = JSON.parse(response.body)

          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['code']).to eq('missing_parameter')
          expect(json_response['errors'].first['detail']).to eq('Required parameter is missing')
        end
      end

      context 'when end time is missing' do
        let(:invalid_params) do
          appointment_params.except(:dt_end_utc)
        end

        it 'returns bad request' do
          redis_client = Vass::RedisClient.build
          redis_client.store_booking_session(
            veteran_id:,
            data: { appointment_id: 'cohort-current-123' }
          )

          post('/vass/v0/appointment',
               params: invalid_params.to_json,
               headers:)

          expect(response).to have_http_status(:bad_request)
          json_response = JSON.parse(response.body)

          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['code']).to eq('missing_parameter')
          expect(json_response['errors'].first['detail']).to eq('Required parameter is missing')
        end
      end

      context 'when session is missing from Redis (token revoked)' do
        before do
          redis_client = Vass::RedisClient.build
          redis_client.delete_session(uuid: veteran_id)
        end

        it 'returns unauthorized status with revoked token error' do
          post('/vass/v0/appointment',
               params: appointment_params.to_json,
               headers:)

          expect(response).to have_http_status(:unauthorized)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['detail']).to eq('Token is invalid or already revoked')
        end
      end

      context 'when VASS API returns an error' do
        before do
          redis_client = Vass::RedisClient.build
          redis_client.store_booking_session(
            veteran_id:,
            data: { appointment_id: 'cohort-current-123' }
          )
        end

        it 'returns bad gateway status' do
          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/save_appointment_invalid_veteran', match_requests_on: %i[method uri]) do
              # Temporarily change veteran_id to trigger error cassette
              allow_any_instance_of(Vass::AppointmentsService).to receive(:save_appointment).and_raise(
                Vass::Errors::VassApiError.new('VASS API error: 400')
              )

              post('/vass/v0/appointment',
                   params: appointment_params.to_json,
                   headers:)

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
end
