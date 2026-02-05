# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Vass::V0::Appointments - Appointment Availability', type: :request do
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:uuid) { 'da1e1a40-1e63-f011-bec2-001dd80351ea' }
  let(:veteran_id) { 'vet-uuid-123' }
  let(:edipi) { '1234567890' }
  let(:jwt_secret) { 'test-jwt-secret' }
  let(:jti) { SecureRandom.uuid }
  let(:jwt_token) do
    # Generate a valid JWT token for testing
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

  describe 'GET /vass/v0/appointment-availability' do
    let(:headers) do
      {
        'Authorization' => "Bearer #{jwt_token}",
        'Content-Type' => 'application/json'
      }
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized status' do
        get '/vass/v0/appointment-availability', headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end
    end

    context 'when user is authenticated' do
      context 'with available slots in current cohort' do
        # Freeze time to be within the cassette cohort dates (2026-01-05 to 2026-01-20)
        # and ensure slots (Jan 10-12) are in the valid "tomorrow to 2 weeks" range
        around do |example|
          Timecop.freeze(DateTime.new(2026, 1, 7).utc) { example.run }
        end

        it 'returns available slots status with appointment data' do
          allow(StatsD).to receive(:increment).and_call_original

          expect(StatsD).to receive(:increment).with(
            'api.vass.controller.appointments.availability.success',
            hash_including(tags: array_including('service:vass', 'endpoint:availability'))
          ).and_call_original

          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/get_appointments_unbooked_cohort', match_requests_on: %i[method uri]) do
              VCR.use_cassette('vass/appointments/get_availability_success', match_requests_on: %i[method uri]) do
                get('/vass/v0/appointment-availability', headers:)

                expect(response).to have_http_status(:ok)
                json_response = JSON.parse(response.body)

                expect(json_response['data']).to be_present
                expect(json_response['data']['appointmentId']).to be_present
                expect(json_response['data']['availableSlots']).to be_an(Array)
                expect(json_response['data']['availableSlots']).not_to be_empty
              end
            end
          end
        end

        it 'stores appointment_id in Redis booking session' do
          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/get_appointments_unbooked_cohort', match_requests_on: %i[method uri]) do
              VCR.use_cassette('vass/appointments/get_availability_success', match_requests_on: %i[method uri]) do
                get('/vass/v0/appointment-availability', headers:)

                expect(response).to have_http_status(:ok)

                # Verify booking session was stored in Redis
                redis_client = Vass::RedisClient.build
                booking_session = redis_client.get_booking_session(veteran_id:)
                expect(booking_session).to be_present
                expect(booking_session[:appointment_id]).to eq('cohort-current-123')
              end
            end
          end
        end

        it 'filters slots to only include capacity > 0' do
          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/get_appointments_unbooked_cohort', match_requests_on: %i[method uri]) do
              VCR.use_cassette('vass/appointments/get_availability_success', match_requests_on: %i[method uri]) do
                get('/vass/v0/appointment-availability', headers:)

                expect(response).to have_http_status(:ok)
                json_response = JSON.parse(response.body)

                # All returned slots should be valid (this is verified by service filtering logic)
                expect(json_response['data']['availableSlots']).to be_an(Array)
                json_response['data']['availableSlots'].each do |slot|
                  expect(slot['dtStartUtc']).to be_present
                  expect(slot['dtEndUtc']).to be_present
                end
              end
            end
          end
        end
      end

      context 'when current cohort has no available slots' do
        # Freeze time to be within the cassette cohort dates (2026-01-05 to 2026-01-20)
        around do |example|
          Timecop.freeze(DateTime.new(2026, 1, 7).utc) { example.run }
        end

        it 'returns no_slots_available error' do
          allow(StatsD).to receive(:increment).and_call_original

          expect(StatsD).to receive(:increment).with(
            'api.vass.infrastructure.availability.no_slots_available',
            hash_including(tags: array_including('service:vass'))
          ).and_call_original

          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/get_appointments_unbooked_cohort', match_requests_on: %i[method uri]) do
              VCR.use_cassette('vass/appointments/get_availability_no_slots', match_requests_on: %i[method uri]) do
                get('/vass/v0/appointment-availability', headers:)

                expect(response).to have_http_status(:unprocessable_content)
                json_response = JSON.parse(response.body)

                expect(json_response['errors']).to be_present
                expect(json_response['errors'].first['code']).to eq('no_slots_available')
                expect(json_response['errors'].first['detail']).to eq('No available appointment slots')
              end
            end
          end
        end

        it 'does not store appointment_id in Redis' do
          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/get_appointments_unbooked_cohort', match_requests_on: %i[method uri]) do
              VCR.use_cassette('vass/appointments/get_availability_no_slots', match_requests_on: %i[method uri]) do
                get('/vass/v0/appointment-availability', headers:)

                expect(response).to have_http_status(:unprocessable_content)

                # No booking session should be created
                redis_client = Vass::RedisClient.build
                booking_session = redis_client.get_booking_session(veteran_id:)
                expect(booking_session).to be_empty
              end
            end
          end
        end
      end

      context 'when current cohort is already booked' do
        # Freeze time to be within the cassette cohort dates (2026-01-05 to 2026-01-20)
        around do |example|
          Timecop.freeze(DateTime.new(2026, 1, 7).utc) { example.run }
        end

        it 'returns conflict status with appointment details' do
          allow(StatsD).to receive(:increment).and_call_original

          expect(StatsD).to receive(:increment).with(
            'api.vass.infrastructure.availability.already_booked',
            hash_including(tags: array_including('service:vass'))
          ).and_call_original

          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/get_appointments_booked_cohort', match_requests_on: %i[method uri]) do
              get('/vass/v0/appointment-availability', headers:)

              expect(response).to have_http_status(:conflict)
              json_response = JSON.parse(response.body)

              expect(json_response['errors']).to be_present
              expect(json_response['errors'].first['code']).to eq('appointment_already_booked')
              expect(json_response['errors'].first['detail']).to eq('already scheduled')
              expect(json_response['errors'].first['appointment']).to be_present
              expect(json_response['errors'].first['appointment']['appointmentId']).to be_present
              expect(json_response['errors'].first['appointment']['dtStartUtc']).to be_present
              expect(json_response['errors'].first['appointment']['dtEndUtc']).to be_present
            end
          end
        end

        it 'does not call availability API' do
          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/get_appointments_booked_cohort', match_requests_on: %i[method uri]) do
              # Should NOT use availability cassette since cohort is already booked
              get('/vass/v0/appointment-availability', headers:)

              expect(response).to have_http_status(:conflict)
              json_response = JSON.parse(response.body)
              expect(json_response['errors'].first['code']).to eq('appointment_already_booked')
            end
          end
        end

        it 'does not store appointment_id in Redis' do
          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/get_appointments_booked_cohort', match_requests_on: %i[method uri]) do
              get('/vass/v0/appointment-availability', headers:)

              expect(response).to have_http_status(:conflict)

              # No booking session should be created for already booked cohorts
              redis_client = Vass::RedisClient.build
              booking_session = redis_client.get_booking_session(veteran_id:)
              expect(booking_session).to be_empty
            end
          end
        end
      end

      context 'when no current cohort exists but future cohorts available' do
        # Freeze time to be before the future cassette cohort (2026-02-15 to 2026-02-28)
        around do |example|
          Timecop.freeze(DateTime.new(2026, 1, 7).utc) { example.run }
        end

        it 'returns success with next cohort details' do
          allow(StatsD).to receive(:increment).and_call_original

          expect(StatsD).to receive(:increment).with(
            'api.vass.infrastructure.availability.next_cohort',
            hash_including(tags: array_including('service:vass'))
          ).and_call_original

          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/get_appointments_future_cohort_only',
                             match_requests_on: %i[method uri]) do
              get('/vass/v0/appointment-availability', headers:)

              expect(response).to have_http_status(:ok)
              json_response = JSON.parse(response.body)

              expect(json_response['data']).to be_present
              expect(json_response['data']['message']).to include('Booking opens on')
              expect(json_response['data']['nextCohort']).to be_present
              expect(json_response['data']['nextCohort']['cohortStartUtc']).to be_present
              expect(json_response['data']['nextCohort']['cohortEndUtc']).to be_present
            end
          end
        end
      end

      context 'when no cohorts are available' do
        it 'returns error with message' do
          allow(StatsD).to receive(:increment).and_call_original

          expect(StatsD).to receive(:increment).with(
            'api.vass.infrastructure.availability.no_cohorts',
            hash_including(tags: array_including('service:vass'))
          ).and_call_original

          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/get_appointments_no_cohorts', match_requests_on: %i[method uri]) do
              get('/vass/v0/appointment-availability', headers:)

              expect(response).to have_http_status(:unprocessable_content)
              json_response = JSON.parse(response.body)

              expect(json_response['errors']).to be_present
              expect(json_response['errors'].first['code']).to eq('not_within_cohort')
              expect(json_response['errors'].first['detail']).to(
                eq('Current date outside of appointment cohort date ranges')
              )
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
          allow(Rails.logger).to receive(:warn).and_call_original
          expect(Rails.logger).to receive(:warn)
            .with(a_string_including('"service":"vass"', '"action":"auth_failure"', '"reason":"revoked_token"'))
            .and_call_original

          get('/vass/v0/appointment-availability', headers:)

          expect(response).to have_http_status(:unauthorized)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['detail']).to eq('Token is invalid or already revoked')
        end
      end

      context 'when VASS API returns an error' do
        it 'returns service unavailable status' do
          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/get_appointments_api_error', match_requests_on: %i[method uri]) do
              get('/vass/v0/appointment-availability', headers:)

              expect(response).to have_http_status(:service_unavailable)
              json_response = JSON.parse(response.body)
              expect(json_response['errors']).to be_present
            end
          end
        end
      end

      context 'when service returns an unexpected status' do
        it 'logs error and returns internal server error' do
          # Mock the service to return an unexpected status
          appointments_service = instance_double(Vass::AppointmentsService)
          allow(Vass::AppointmentsService).to receive(:build).and_return(appointments_service)
          allow(appointments_service).to receive(:get_current_cohort_availability).and_return(
            {
              status: :unexpected_status,
              data: {}
            }
          )

          allow(Rails.logger).to receive(:error)

          get('/vass/v0/appointment-availability', headers:)

          expect(response).to have_http_status(:internal_server_error)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['code']).to eq('internal_error')
          expect(json_response['errors'].first['detail']).to eq('An unexpected error occurred')

          expect(Rails.logger).to have_received(:error).with(
            a_string_including(
              '"service":"vass"',
              '"controller":"appointments"',
              '"action":"unexpected_availability_status"',
              '"status":"unexpected_status"'
            )
          )
        end
      end
    end
  end
end
