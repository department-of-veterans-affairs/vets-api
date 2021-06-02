# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'facilities', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'with a loa3 user' do
    let(:user) { build(:user, :mhv) }

    describe 'GET facilities' do
      context 'on successful query for a facility' do
        it 'returns facility details' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_200', match_requests_on: %i[method uri]) do
            get '/vaos/v2/facilities?ids=688', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_camelized_response_schema('vaos/v2/get_facilities', { strict: false })
          end
        end
      end

      context 'on successful query for a facility and children' do
        it 'returns facility details' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_with_children_200',
                           match_requests_on: %i[method uri]) do
            get '/vaos/v2/facilities?ids=688&children=true', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_camelized_response_schema('vaos/v2/get_facilities', { strict: false })
          end
        end
      end

      context 'on sending a bad request to the VAOS Service' do
        it 'returns a 400 http status' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_400', match_requests_on: %i[method uri]) do
            get '/vaos/v2/facilities?ids=688'
            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_400')
          end
        end
      end
    end
  end
end
