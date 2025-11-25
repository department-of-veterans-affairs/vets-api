# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS::V2::EpsAppointments', :skip_mvi, type: :request do
  include SchemaMatchers

  let(:access_token) { 'fake-access-token' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:described_class) { VAOS::V2::EpsAppointmentsController }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  before do
    allow(Settings.mhv).to receive(:facility_range).and_return([[1, 999]])
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')

    # Setup a memory store for caching instead of using Rails.cache
    allow(Rails).to receive(:cache).and_return(memory_store)
    # Cache the token for EPS service
    Rails.cache.write(Eps::BaseService::REDIS_TOKEN_KEY, access_token)

    Settings.vaos ||= OpenStruct.new
    Settings.vaos.eps ||= OpenStruct.new
    Settings.vaos.eps.tap do |eps|
      eps.api_url = 'https://api.wellhive.com'
    end
  end

  context 'for eps referrals' do
    let(:current_user) { build(:user, :vaos, icn: 'care-nav-patient-casey') }

    describe 'get eps appointment' do
      let(:expected_response) do
        {
          'data' => {
            'id' => 'qdm61cJ5',
            'type' => 'epsAppointment',
            'attributes' => {
              'id' => 'qdm61cJ5',
              'status' => 'booked',
              'start' => '2024-11-21T18:00:00Z',
              'isLatest' => true,
              'lastRetrieved' => '2025-02-10T14:35:44Z',
              'modality' => 'communityCareEps',
              'location' => {
                'id' => 'Aq7wgAux',
                'type' => 'appointments',
                'attributes' => {
                  'name' => 'Test Medical Complex',
                  'timezone' => {
                    'timeZoneId' => 'America/New_York'
                  }
                }
              },
              'provider' => {
                'id' => 'test-provider-id',
                'name' => 'Timothy Bob',
                'practice' => 'test-provider-org-name',
                'location' => {
                  'name' => 'Test Medical Complex',
                  'address' => '207 Davishill Ln',
                  'latitude' => 33.058736,
                  'longitude' => -80.032819,
                  'timezone' => 'America/New_York'
                }
              },
              'past' => true,
              'referralId' => '12345'
            }
          }
        }
      end

      context 'booked appointment' do
        it 'successfully returns by id' do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/eps/get_appointment/booked_200', match_requests_on: %i[method path]) do
              VCR.use_cassette('vaos/eps/providers/data_Aq7wgAux_200', match_requests_on: %i[method path]) do
                expect(StatsD).to receive(:increment).with(
                  'api.vaos.eps_appointment_detail.access',
                  tags: ['service:community_care_appointments']
                ).and_call_original
                allow(StatsD).to receive(:increment).and_call_original

                get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header

                expect(response).to have_http_status(:success)
                expect(JSON.parse(response.body)).to eq(expected_response)
              end
            end
          end
        end
      end

      context 'when a booked appointment corresponding to the referral is not found' do
        let(:perform_request) do
          lambda do
            VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
              VCR.use_cassette('vaos/eps/get_appointment/404', match_requests_on: %i[method path]) do
                get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header
              end
            end
          end
        end

        it 'returns a 404 error' do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/eps/get_appointment/404', match_requests_on: %i[method path]) do
              get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header

              expect(response).to have_http_status(:not_found)
            end
          end
        end

        it 'logs EPS error with sanitized context' do
          allow(Rails.logger).to receive(:error)

          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/eps/get_appointment/404', match_requests_on: %i[method path]) do
              get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header
            end
          end

          # The service logs the error when processing real VCR responses
          # Verify controller name comes from RequestStore (set by controller's before_action)
          expected_controller_name = 'VAOS::V2::EpsAppointmentsController'
          # Verify station_number comes from user object
          expected_station_number = current_user.va_treatment_facility_ids&.first

          expect(Rails.logger).to have_received(:error).with(
            'Community Care Appointments: EPS service error',
            {
              service: 'EPS',
              method: 'get_appointment',
              error_class: 'Eps::ServiceException',
              timestamp: a_string_matching(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/),
              controller: expected_controller_name,
              station_number: expected_station_number,
              eps_trace_id: '1dba6dccb4a50f0c512d5bd661ebc013',
              code: 'VAOS_404',
              upstream_status: 404,
              upstream_body: '{\"name\": \"Not Found\"}'
            }
          )
        end
      end

      context 'when the upstream service returns a 500 error' do
        let(:perform_request) do
          lambda do
            VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
              VCR.use_cassette('vaos/eps/get_appointment/500', match_requests_on: %i[method path]) do
                get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header
              end
            end
          end
        end

        it 'returns a 502 error' do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/eps/get_appointment/500', match_requests_on: %i[method path]) do
              get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header

              expect(response).to have_http_status(:bad_gateway)
            end
          end
        end

        it 'logs EPS error with sanitized context' do
          allow(Rails.logger).to receive(:error)

          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/eps/get_appointment/500', match_requests_on: %i[method path]) do
              get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header
            end
          end

          # The service logs the error when processing real VCR responses
          # Verify controller name comes from RequestStore (set by controller's before_action)
          expected_controller_name = 'VAOS::V2::EpsAppointmentsController'
          # Verify station_number comes from user object
          expected_station_number = current_user.va_treatment_facility_ids&.first

          expect(Rails.logger).to have_received(:error).with(
            'Community Care Appointments: EPS service error',
            {
              service: 'EPS',
              method: 'get_appointment',
              error_class: 'Eps::ServiceException',
              timestamp: a_string_matching(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/),
              controller: expected_controller_name,
              station_number: expected_station_number,
              code: 'VAOS_502',
              upstream_status: 500,
              upstream_body: '{\"isFault\": true,\"isTemporary\": true,\"name\": \"Internal Server Error\"}'
            }
          )
        end
      end

      context 'draft appointment' do
        it 'returns 404' do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/eps/get_appointment/draft_200', match_requests_on: %i[method path]) do
              get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header

              expect(response).to have_http_status(:success)
              expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('proposed')
            end
          end
        end
      end

      context 'location data' do
        it 'includes location key in response when provider data is available' do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/eps/get_appointment/booked_200', match_requests_on: %i[method path]) do
              VCR.use_cassette('vaos/eps/providers/data_Aq7wgAux_200', match_requests_on: %i[method path]) do
                get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header

                expect(response).to have_http_status(:success)
                response_data = JSON.parse(response.body)

                expect(response_data['data']['attributes']).to have_key('location')

                location = response_data['data']['attributes']['location']
                expect(location).to be_present
                expect(location['id']).to be_present
                expect(location['type']).to eq('appointments')
                expect(location['attributes']).to be_present
                expect(location['attributes']['name']).to eq('Test Medical Complex')
                expect(location['attributes']['timezone']).to be_present
                expect(location['attributes']['timezone']['timeZoneId']).to eq('America/New_York')
              end
            end
          end
        end

        it 'handles missing provider data gracefully' do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/eps/get_appointment/draft_200', match_requests_on: %i[method path]) do
              get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header

              expect(response).to have_http_status(:success)
              response_data = JSON.parse(response.body)

              expect(response_data['data']['attributes']['location']).to be_nil
            end
          end
        end
      end

      context 'when response contains error field' do
        let(:perform_request) do
          lambda do
            # Raise Eps::ServiceException with proper BackendServiceException parameters
            allow_any_instance_of(Eps::AppointmentService).to receive(:get_appointment)
              .and_raise(Eps::ServiceException.new(
                           'VAOS_400',
                           { code: 'VAOS_400', detail: 'conflict' },
                           400,
                           '{"error": "conflict", "id": "qdm61cJ5"}'
                         ))

            get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header
          end
        end

        it 'returns a 400 error' do
          perform_request.call
          expect(response).to have_http_status(:bad_request)
        end

        it 'logs EPS error with sanitized context' do
          allow(Rails.logger).to receive(:error)

          perform_request.call

          # The global exception handler logs BackendServiceException differently
          expect(Rails.logger).to have_received(:error).with(
            a_string_including('BackendServiceException'),
            hash_including(
              title: 'Bad Request',
              detail: 'conflict',
              code: 'VAOS_400',
              status: '400'
            )
          )
        end
      end
    end
  end
end
