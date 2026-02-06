# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS::V2::Facilities', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling') # rubocop:disable Project/ForbidFlipperToggleInSpecs
    allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_vaos_alternate_route).and_return(false)
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'with a loa3 user' do
    let(:user) { build(:user, :mhv) }

    describe 'GET facilities' do
      context 'on successful query for a facility' do
        it 'returns facility details' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_single_id_200',
                           match_requests_on: %i[method path query]) do
            get '/vaos/v2/facilities?ids=688&schedulable=true', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_camelized_response_schema('vaos/v2/get_facilities', { strict: false })
          end
        end
      end

      context 'on successful query for a facility given multiple facilities in array form' do
        it 'returns facility details' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_200',
                           match_requests_on: %i[method path query]) do
            get '/vaos/v2/facilities?ids[]=983&ids[]=984&schedulable=true', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['data'].size).to eq(2)
            expect(response).to match_camelized_response_schema('vaos/v2/get_facilities', { strict: false })
          end
        end
      end

      context 'query for facilities and not passing in schedulable' do
        it 'sets schedulable to true and returns facility details' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_200',
                           match_requests_on: %i[method path query]) do
            get '/vaos/v2/facilities?ids[]=983&ids[]=984', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['data'].size).to eq(2)
            expect(response).to match_camelized_response_schema('vaos/v2/get_facilities', { strict: false })
          end
        end
      end

      context 'on successful query for a facility and children' do
        it 'returns facility details' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_with_children_schedulable_200',
                           match_requests_on: %i[method path query]) do
            get '/vaos/v2/facilities?ids=688&children=true&schedulable=true', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data'].size).to eq(8)
            expect(response).to match_camelized_response_schema('vaos/v2/get_facilities', { strict: false })
          end
        end
      end

      context 'on sending a bad request to the VAOS Service - missing ids param' do
        it 'returns a 400 http status' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_400',
                           match_requests_on: %i[method path query]) do
            get '/vaos/v2/facilities?schedulable=true'
            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['errors'][0]['status']).to eq('400')
          end
        end
      end

      context 'with sort by recent location' do
        let(:user) { build(:user, :vaos) }

        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                    instance_of(User)).and_return(false)
          allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(false)
          allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details,
                                                    instance_of(User)).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:appointments_consolidation, instance_of(User)).and_return(true)
        end

        it 'returns facilities by recency then by alphabetical order' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_200_sort_by_recent_locations',
                           match_requests_on: %i[method path query]) do
            Timecop.travel(Time.zone.local(2023, 8, 31, 13, 0, 0)) do
              get '/vaos/v2/facilities?ids[]=983&ids[]=983GB&ids[]=983GC&ids[]=983GD&sort_by=recentLocations',
                  headers: inflection_header
              expect(response).to have_http_status(:ok)
              facilities = JSON.parse(response.body)['data']
              expect(facilities.size).to eq(4)
              expect(facilities.pluck('id')).to eq %w[983GC 983 983GD 983GB]
            end
          end
        end

        it 'returns facilities by alphabetical order on unsuccessful query for appointment' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_200_sort_by_recent_locations',
                           match_requests_on: %i[method path query]) do
            expect_any_instance_of(VAOS::V2::AppointmentsService)
              .to receive(:get_sorted_recent_appointments)
              .and_return(nil)
            get '/vaos/v2/facilities?ids[]=983&ids[]=983GB&ids[]=983GC&ids[]=983GD&sort_by=recentLocations',
                headers: inflection_header
            expect(response).to have_http_status(:ok)
            facilities = JSON.parse(response.body)['data']
            expect(facilities.size).to eq(4)
            expect(facilities.pluck('id')).to eq %w[983 983GC 983GD 983GB]
          end
        end
      end
    end

    describe 'SHOW facilities' do
      context 'on successful query for a facility' do
        it 'returns facility details' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                           match_requests_on: %i[method path query]) do
            get '/vaos/v2/facilities/983', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_camelized_response_schema('vaos/v2/get_facility', { strict: false })
          end
        end
      end

      context 'on sending a bad request to the VAOS Service' do
        it 'returns a 400 http status' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_400',
                           match_requests_on: %i[method path query]) do
            get '/vaos/v2/facilities/983'
            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_400')
          end
        end
      end
    end
  end
end
