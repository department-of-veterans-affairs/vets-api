# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::SchedulingController, type: :request, skip_mvi: true do
  include SchemaMatchers

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }
  let(:current_user) { build(:user, :vaos) }

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  context 'with vaos user' do
    describe 'GET scheduling/configurations' do
      context 'has access and is given single facility id' do
        it 'returns a single scheduling configuration' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_200',
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
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_200',
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
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_200',
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
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_200',
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
  end
end
