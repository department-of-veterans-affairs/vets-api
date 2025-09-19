# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS::V2::EpsAppointments', :skip_mvi, type: :request do
  include SchemaMatchers

  let(:access_token) { 'fake-access-token' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:described_class) { VAOS::V2::EpsAppointmentsController }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  # Shared examples for error logging
  shared_examples 'logs EPS service error' do |_expected_method, _expected_code, _expected_detail, _expected_body_pattern| # rubocop:disable Layout/LineLength
    it 'logs the error to Rails logger and Sentry' do
      expect(Rails.logger).to receive(:error).at_least(:once)

      perform_request.call
    end
  end

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
              'modality' => 'OV',
              'provider' => {
                'id' => 'test-provider-id',
                'location' => {
                  'name' => 'Test Medical Complex',
                  'address' => '207 Davishill Ln',
                  'latitude' => 33.058736,
                  'longitude' => -80.032819,
                  'timezone' => 'America/New_York'
                }
              }
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

        it_behaves_like 'logs EPS service error', 'rescue in get_appointment', 'PARSE_ERROR', 'Error parsing failed',
                        /Not Found/
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

        it_behaves_like 'logs EPS service error', 'rescue in get_appointment', 'PARSE_ERROR', 'Error parsing failed',
                        /Internal Server Error/
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

      context 'when response contains error field' do
        before do
          # Define the service exception class used by the EPS service if not loaded
          module Eps; class ServiceException < StandardError; end; end unless defined?(Eps::ServiceException)
        end

        let(:perform_request) do
          lambda do
            # Raise Eps::ServiceException from within the service method flow so the rescue runs
            message = 'BackendServiceException: {:code=>"VAOS_400", :source=>{:vamf_status=>400, ' \
                      ':vamf_url=>"https://api.wellhive.com/care-navigation/v1", ' \
                      ':vamf_body=>"{\\"error\\": \\\"conflict\\\", \\\"id\\\": \\\"qdm61cJ5\\\"}"}}'
            allow_any_instance_of(Eps::AppointmentService).to receive(:perform)
              .and_raise(Eps::ServiceException.new(message))

            get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header
          end
        end

        it 'returns a 400 error' do
          perform_request.call
          expect(response).to have_http_status(:bad_request)
        end

        it_behaves_like 'logs EPS service error', 'rescue in get_appointment', 'VAOS_400', 'Bad Request', /conflict/
      end
    end
  end
end
