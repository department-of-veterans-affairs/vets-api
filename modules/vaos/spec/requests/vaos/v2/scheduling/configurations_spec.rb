# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS::V2::Scheduling::Configurations', :skip_mvi, type: :request do
  include SchemaMatchers

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }
  let(:current_user) { build(:user, :vaos) }

  before do
    Flipper.enable('va_online_scheduling')
    allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_vaos_alternate_route).and_return(false)
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  context 'with vaos user' do
    describe 'GET scheduling/configurations' do
      context 'with CSCS' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_cscs_migration,
                                                    instance_of(User)).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                    instance_of(User)).and_return(false)
        end

        context 'has access and is given single facility id' do
          it 'returns a single scheduling configuration' do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_cscs_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/scheduling/configurations?facility_ids=489', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)
              expect(JSON.parse(response.body)['data'].size).to eq(1)
              expect(response.body).to match_camelized_schema('vaos/v2/scheduling_configurations', { strict: false })
            end
          end
        end

        context 'has access and is given multiple facility ids as CSV' do
          it 'returns scheduling configurations' do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_cscs_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/scheduling/configurations?facility_ids=489,984', headers: inflection_header
              expect(response).to have_http_status(:ok)
              data = JSON.parse(response.body)['data']
              expect(data.size).to eq(2)
              expect(response.body).to match_camelized_schema('vaos/v2/scheduling_configurations', { strict: false })
            end
          end
        end

        context 'has access and is given multiple facility ids as []=' do
          it 'returns scheduling configurations' do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_cscs_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/scheduling/configurations?facility_ids[]=489&facility_ids[]=984', headers: inflection_header
              expect(response).to have_http_status(:ok)
              data = JSON.parse(response.body)['data']
              expect(data.size).to eq(2)
              expect(response.body).to match_camelized_schema('vaos/v2/scheduling_configurations', { strict: false })
            end
          end
        end

        context 'has access and is given multiple facility ids and cc enable parameters' do
          it 'returns scheduling configurations' do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_cscs_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/scheduling/configurations?cc_enabled=true&facility_ids[]=489&facility_ids[]=984',
                  headers: inflection_header
              expect(response).to have_http_status(:ok)
              data = JSON.parse(response.body)['data']
              expect(data.size).to eq(1)
              expect(response.body).to match_camelized_schema('vaos/v2/scheduling_configurations', { strict: false })
            end
          end
        end
      end

      context 'with MFS' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_cscs_migration,
                                                    instance_of(User)).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                    instance_of(User)).and_return(false)
        end

        context 'has access and is given single facility id' do
          it 'returns a single scheduling configuration' do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_mfs_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/scheduling/configurations?facility_ids=489', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)
              expect(JSON.parse(response.body)['data'].size).to eq(1)
              expect(response.body).to match_camelized_schema('vaos/v2/scheduling_configurations', { strict: false })
            end
          end
        end

        context 'has access and is given multiple facility ids as CSV' do
          it 'returns scheduling configurations' do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_mfs_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/scheduling/configurations?facility_ids=489,984', headers: inflection_header
              expect(response).to have_http_status(:ok)
              data = JSON.parse(response.body)['data']
              expect(data.size).to eq(2)
              expect(response.body).to match_camelized_schema('vaos/v2/scheduling_configurations', { strict: false })
            end
          end
        end

        context 'has access and is given multiple facility ids as []=' do
          it 'returns scheduling configurations' do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_mfs_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/scheduling/configurations?facility_ids[]=489&facility_ids[]=984', headers: inflection_header
              expect(response).to have_http_status(:ok)
              data = JSON.parse(response.body)['data']
              expect(data.size).to eq(2)
              expect(response.body).to match_camelized_schema('vaos/v2/scheduling_configurations', { strict: false })
            end
          end
        end

        context 'has access and is given multiple facility ids and cc enable parameters' do
          it 'returns scheduling configurations' do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_mfs_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/scheduling/configurations?cc_enabled=true&facility_ids[]=489&facility_ids[]=984',
                  headers: inflection_header
              expect(response).to have_http_status(:ok)
              data = JSON.parse(response.body)['data']
              expect(data.size).to eq(1)
              expect(response.body).to match_camelized_schema('vaos/v2/scheduling_configurations', { strict: false })
            end
          end
        end
      end

      context 'with VPG' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                    instance_of(User)).and_return(true)
        end

        context 'has access and is given single facility id' do
          it 'returns a single scheduling configuration' do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_vpg_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/scheduling/configurations?facility_ids=653', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)
              expect(JSON.parse(response.body)['data'].size).to eq(1)
              expect(response.body).to match_camelized_schema('vaos/v2/vpg_scheduling_configurations',
                                                              { strict: false })
            end
          end
        end

        context 'has access and is given multiple facility ids as CSV' do
          it 'returns scheduling configurations' do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_vpg_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/scheduling/configurations?facility_ids=653,687', headers: inflection_header
              expect(response).to have_http_status(:ok)
              data = JSON.parse(response.body)['data']
              expect(data.size).to eq(2)
              expect(response.body).to match_camelized_schema('vaos/v2/vpg_scheduling_configurations',
                                                              { strict: false })
            end
          end
        end

        context 'has access and is given multiple facility ids as []=' do
          it 'returns scheduling configurations' do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_vpg_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/scheduling/configurations?facility_ids[]=653&facility_ids[]=687', headers: inflection_header
              expect(response).to have_http_status(:ok)
              data = JSON.parse(response.body)['data']
              expect(data.size).to eq(2)
              expect(response.body).to match_camelized_schema('vaos/v2/vpg_scheduling_configurations',
                                                              { strict: false })
            end
          end
        end

        context 'has access and is given multiple facility ids and cc enable parameters' do
          it 'returns scheduling configurations' do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_vpg_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/scheduling/configurations?cc_enabled=true&facility_ids[]=523&facility_ids[]=534',
                  headers: inflection_header
              expect(response).to have_http_status(:ok)
              data = JSON.parse(response.body)['data']
              expect(data.size).to eq(2)
              expect(response.body).to match_camelized_schema('vaos/v2/vpg_scheduling_configurations',
                                                              { strict: false })
            end
          end
        end
      end
    end
  end
end
