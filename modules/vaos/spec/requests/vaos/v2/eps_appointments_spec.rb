# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS::V2::EpsAppointments', :skip_mvi, type: :request do
  include SchemaMatchers

  before do
    allow(Settings.mhv).to receive(:facility_range).and_return([[1, 999]])
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:described_class) { VAOS::V2::EpsAppointmentsController }

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'for eps referrals' do
    let(:current_user) { build(:user, :vaos, icn: 'care-nav-patient-casey') }

    describe 'get eps appointment' do
      context 'when a booked appointment corresponding to the referral exists' do
        let(:expected_response) do
          {
            'data' => {
              'id' => 'qdm61cJ5',
              'type' => 'eps_appointment',
              'attributes' => {
                'appointment' => {
                  'id' => 'qdm61cJ5',
                  'status' => 'booked',
                  'patientIcn' => 'care-nav-patient-casey',
                  'created' => '2025-02-10T14:35:44Z',
                  'locationId' => 'sandbox-network-5vuTac8v',
                  'clinic' => 'Aq7wgAux',
                  'start' => '2024-11-21T18:00:00Z',
                  'referralId' => '12345',
                  'referral' => { 'referralNumber' => '12345' },
                  'providerServiceId' => 'Aq7wgAux',
                  'providerName' => 'unknown'
                },
                'provider' => {
                  'id' => 'test-provider-id',
                  'name' => 'Timothy Bob',
                  'isActive' => true,
                  'individualProviders' => [
                    {
                      'name' => 'Timothy Bob', 'npi' => 'test-npi'
                    }
                  ],
                  'providerOrganization' => {
                    'name' => 'test-provider-org-name'
                  },
                  'location' => {
                    'name' => 'Test Medical Complex',
                    'address' => '207 Davishill Ln',
                    'latitude' => 33.058736,
                    'longitude' => -80.032819,
                    'timezone' => 'America/New_York'
                  },
                  'networkIds' => [
                    'sandbox-network-test'
                  ],
                  'schedulingNotes' => 'New patients need to send their previous records to the office prior to their' \
                                       ' appt.',
                  'appointmentTypes' => [
                    {
                      'id' => 'off',
                      'name' => 'Office Visit',
                      'isSelfSchedulable' => true
                    }
                  ],
                  'specialties' => [
                    {
                      'id' => 'test-id',
                      'name' => 'Urology'
                    }
                  ],
                  'visitMode' => 'phone',
                  'features' => nil
                }
              }
            }
          }
        end

        it 'successfully returns by id' do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/eps/get_appointment/booked_200', match_requests_on: %i[method path query]) do
              VCR.use_cassette('vaos/eps/providers/data_Aq7wgAux_200', match_requests_on: %i[method path query]) do
                get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header

                expect(response).to have_http_status(:success)
                expect(JSON.parse(response.body)).to eq(expected_response)
              end
            end
          end
        end
      end

      context 'when a booked appointment corresponding to the referral is not found' do
        it 'returns a 404 error' do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/eps/get_appointment/404', match_requests_on: %i[method path query]) do
              get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header

              expect(response).to have_http_status(:not_found)
            end
          end
        end
      end

      context 'when the upstream service returns a 500 error' do
        it 'returns a 502 error' do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/eps/get_appointment/500', match_requests_on: %i[method path query]) do
              get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header

              expect(response).to have_http_status(:bad_gateway)
            end
          end
        end
      end

      context 'draft appointment' do
        it 'returns 404' do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/eps/get_appointment/draft_200', match_requests_on: %i[method path query]) do
              get '/vaos/v2/eps_appointments/qdm61cJ5', headers: inflection_header

              expect(response).to have_http_status(:not_found)
            end
          end
        end
      end
    end
  end
end
