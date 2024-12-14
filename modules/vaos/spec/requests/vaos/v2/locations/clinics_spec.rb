# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS::V2::Locations::Clinics', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    Flipper.disable(:va_online_scheduling_vaos_alternate_route)
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'with a loa3 user' do
    let(:user) { build(:user, :mhv) }

    describe 'GET facility clinics' do
      context 'using VAOS' do
        before do
          Flipper.disable(:va_online_scheduling_use_vpg)
        end

        context 'on successful query for clinics given service type' do
          it 'returns a list of clinics' do
            VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200', match_requests_on: %i[method path query]) do
              get '/vaos/v2/locations/983/clinics?clinical_service=audiology', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(response.body).to match_camelized_schema('vaos/v2/clinics', { strict: false })
              x = JSON.parse(response.body)
              expect(x['data'].size).to eq(7)
              expect(x['data'][0]['id']).to eq('570')
              expect(x['data'][0]['type']).to eq('clinics')
              expect(x['data'][0]['attributes']['serviceName']).to eq('CHY C&P AUDIO')
            end
          end
        end

        context 'on successful query for clinics given csv clinic ids' do
          it 'returns a list of clinics' do
            VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200', match_requests_on: %i[method path query]) do
              get '/vaos/v2/locations/983/clinics?clinic_ids=570,945', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(response.body).to match_camelized_schema('vaos/v2/clinics', { strict: false })
              x = JSON.parse(response.body)
              expect(x['data'].size).to eq(2)
              expect(x['data'][1]['id']).to eq('945')
              expect(x['data'][1]['type']).to eq('clinics')
              expect(x['data'][1]['attributes']['serviceName']).to eq('FTC C&P AUDIO BEV')
            end
          end
        end

        context 'on successful query for clinics given array clinic ids' do
          it 'returns a list of clinics' do
            VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200', match_requests_on: %i[method path query]) do
              get '/vaos/v2/locations/983/clinics?clinic_ids[]=570&clinic_ids[]=945', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(response.body).to match_camelized_schema('vaos/v2/clinics', { strict: false })
              expect(JSON.parse(response.body)['data'].size).to eq(2)
            end
          end
        end

        context 'on successful query for clinics given an array with a single clinic id' do
          it 'returns a single clinic' do
            VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200', match_requests_on: %i[method path query]) do
              get '/vaos/v2/locations/983/clinics?clinic_ids[]=570', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(response.body).to match_camelized_schema('vaos/v2/clinics', { strict: false })
              expect(JSON.parse(response.body)['data'].size).to eq(1)
            end
          end
        end

        context 'on successful query for clinics given an array with a single clinic id when camel-inflected' do
          it 'returns a single clinic' do
            VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200', match_requests_on: %i[method path query]) do
              get '/vaos/v2/locations/983/clinics?clinic_ids[]=570', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(JSON.parse(response.body)['data'].size).to eq(1)
              expect(response.body).to match_camelized_schema('vaos/v2/clinics')
            end
          end
        end

        context 'on sending a bad request to the VAOS Service' do
          it 'returns a 400 http status' do
            VCR.use_cassette('vaos/v2/systems/get_facility_clinics_400', match_requests_on: %i[method path query]) do
              get '/vaos/v2/locations/983/clinics?clinic_ids[]=570&clinical_service=audiology'
              expect(response).to have_http_status(:bad_request)
              expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_400')
            end
          end
        end
      end

      context 'using VPG' do
        before do
          Flipper.enable(:va_online_scheduling_use_vpg)
        end

        context 'on successful query for clinics given service type' do
          it 'returns a list of clinics' do
            VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200_vpg',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/locations/983/clinics?clinical_service=audiology', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(response.body).to match_camelized_schema('vaos/v2/clinics', { strict: false })
              x = JSON.parse(response.body)
              expect(x['data'].size).to eq(7)
              expect(x['data'][0]['id']).to eq('570')
              expect(x['data'][0]['type']).to eq('clinics')
              expect(x['data'][0]['attributes']['serviceName']).to eq('CHY C&P AUDIO')
            end
          end
        end

        context 'on successful query for clinics given csv clinic ids' do
          it 'returns a list of clinics' do
            VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200_vpg',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/locations/983/clinics?clinic_ids=570,945', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(response.body).to match_camelized_schema('vaos/v2/clinics', { strict: false })
              x = JSON.parse(response.body)
              expect(x['data'].size).to eq(2)
              expect(x['data'][1]['id']).to eq('945')
              expect(x['data'][1]['type']).to eq('clinics')
              expect(x['data'][1]['attributes']['serviceName']).to eq('FTC C&P AUDIO BEV')
            end
          end
        end

        context 'on successful query for clinics given array clinic ids' do
          it 'returns a list of clinics' do
            VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200_vpg',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/locations/983/clinics?clinic_ids[]=570&clinic_ids[]=945', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(response.body).to match_camelized_schema('vaos/v2/clinics', { strict: false })
              expect(JSON.parse(response.body)['data'].size).to eq(2)
            end
          end
        end

        context 'on successful query for clinics given an array with a single clinic id' do
          it 'returns a single clinic' do
            VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200_vpg',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/locations/983/clinics?clinic_ids[]=570', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(response.body).to match_camelized_schema('vaos/v2/clinics', { strict: false })
              expect(JSON.parse(response.body)['data'].size).to eq(1)
            end
          end
        end

        context 'on successful query for clinics given an array with a single clinic id when camel-inflected' do
          it 'returns a single clinic' do
            VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200_vpg',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/locations/983/clinics?clinic_ids[]=570', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(JSON.parse(response.body)['data'].size).to eq(1)
              expect(response.body).to match_camelized_schema('vaos/v2/clinics')
            end
          end
        end

        context 'on sending a bad request to the VAOS Service' do
          it 'returns a 400 http status' do
            VCR.use_cassette('vaos/v2/systems/get_facility_clinics_400_vpg',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/locations/983/clinics?clinic_ids[]=570&clinical_service=audiology'
              expect(response).to have_http_status(:bad_request)
              expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_400')
            end
          end
        end
      end
    end

    describe 'GET last visited clinic' do
      let(:user) { build(:user, :vaos) }

      context 'using VAOS' do
        before do
          Flipper.disable(:va_online_scheduling_use_vpg)
        end

        context 'on successful query for last visited clinic' do
          it 'returns the last visited clinic' do
            VCR.use_cassette('vaos/v2/systems/get_last_visited_clinic_200', match_requests_on: %i[method path query]) do
              Timecop.travel(Time.zone.local(2023, 8, 31, 13, 0, 0)) do
                get '/vaos/v2/locations/last_visited_clinic', headers: inflection_header
                expect(response).to have_http_status(:ok)
                clinic_info = JSON.parse(response.body)['data']['attributes']
                expect(clinic_info['stationId']).to eq('983')
                expect(clinic_info['id']).to eq('1038')
              end
            end
          end
        end

        context 'on unsuccessful query for latest appointment within look back limit' do
          it 'returns a 404 http status' do
            expect_any_instance_of(VAOS::V2::AppointmentsService)
              .to receive(:get_most_recent_visited_clinic_appointment)
              .and_return(nil)
            get '/vaos/v2/locations/last_visited_clinic', headers: inflection_header
            expect(response).to have_http_status(:not_found)
          end
        end

        context 'on unsuccessful query for clinic information' do
          it 'returns a 400 http status' do
            expect_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic_with_cache).and_return(nil)
            VCR.use_cassette('vaos/v2/systems/get_last_visited_clinic_200', match_requests_on: %i[method path query]) do
              Timecop.travel(Time.zone.local(2023, 8, 31, 13, 0, 0)) do
                get '/vaos/v2/locations/last_visited_clinic', headers: inflection_header
                expect(response).to have_http_status(:not_found)
              end
            end
          end
        end
      end
    end

    describe 'GET recent facilities' do
      let(:user) { build(:user, :vaos) }

      context 'using VAOS' do
        before do
          # VPG routes do not exist for the MFS calls made for this scenario
          Flipper.disable(:va_online_scheduling_use_vpg)
        end

        context 'on successful query for recent sorted facilities' do
          it 'returns the recent sorted facilities' do
            VCR.use_cassette('vaos/v2/systems/get_recent_facilities_200',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              Timecop.travel(Time.zone.local(2023, 8, 31, 13, 0, 0)) do
                get '/vaos/v2/locations/recent_facilities', headers: inflection_header
                expect(response).to have_http_status(:ok)
                facility_info = JSON.parse(response.body)['data']
                expect(facility_info[0]['attributes']['id']).to eq('983')
                expect(facility_info[0]['attributes']['name']).to eq('Cheyenne VA Medical Center')
              end
            end
          end
        end

        context 'on unsuccessful query for appointment within look back limit' do
          it 'returns a 404 http status' do
            expect_any_instance_of(VAOS::V2::AppointmentsService)
              .to receive(:get_recent_sorted_appointments)
              .and_return(nil)
            get '/vaos/v2/locations/recent_facilities', headers: inflection_header
            expect(response).to have_http_status(:not_found)
          end
        end

        context 'on unsuccessful query for facility information' do
          it 'does not populate the sorted facility list' do
            allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility).and_return(nil)
            VCR.use_cassette('vaos/v2/systems/get_recent_facilities_200',
                             match_requests_on: %i[method path query]) do
              Timecop.travel(Time.zone.local(2023, 8, 31, 13, 0, 0)) do
                get '/vaos/v2/locations/recent_facilities', headers: inflection_header
                expect(JSON.parse(response.body)['data']).to eq([])
              end
            end
          end
        end
      end
    end
  end
end
