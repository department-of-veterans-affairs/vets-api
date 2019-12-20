# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'systems', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  context 'with a loa1 user' do
    let(:user) { FactoryBot.create(:user, :loa1) }

    it 'returns a forbidden error' do
      get '/v0/vaos/systems'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('You do not have access to online scheduling')
    end
  end

  context 'with a loa3 user' do
    let(:user) { build(:user, :mhv) }
    let(:error_code) { JSON.parse(response.body)['errors'].first['code'] }

    describe 'GET /v0/vaos/systems' do
      context 'with a valid GET systems response' do
        it 'returns a 200 with the correct schema' do
          VCR.use_cassette('vaos/systems/get_systems', match_requests_on: %i[method uri]) do
            expect { get '/v0/vaos/systems' }
              .to trigger_statsd_increment('api.external_http_request.VAOS.success', times: 1, value: 1)

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_response_schema('vaos/systems')
          end
        end
      end

      context 'with a 403 response' do
        it 'returns a VAOS 403 error response' do
          VCR.use_cassette('vaos/systems/get_systems_403', match_requests_on: %i[method uri]) do
            get '/v0/vaos/systems'

            expect(response).to have_http_status(:forbidden)
            expect(error_code).to eq('VAOS_403')
            expect(response).to match_response_schema('errors')
          end
        end
      end

      context 'with a timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it 'returns the default 504 error response' do
          VCR.use_cassette('vaos/systems/get_systems', match_requests_on: %i[method uri]) do
            get '/v0/vaos/systems'
            expect(response).to have_http_status(:gateway_timeout)
            expect(error_code).to eq('504')
          end
        end
      end

      context 'with a 500 response' do
        it 'returns a VAOS 500 error response' do
          VCR.use_cassette('vaos/systems/get_systems_500', match_requests_on: %i[method uri]) do
            get '/v0/vaos/systems'

            expect(response).to have_http_status(:bad_gateway)
            expect(error_code).to eq('VAOS_502')
            expect(response).to match_response_schema('errors')
          end
        end
      end

      context 'with an unmapped error' do
        it 'returns the default VA900 response' do
          VCR.use_cassette('vaos/systems/get_systems_420', match_requests_on: %i[method uri]) do
            get '/v0/vaos/systems'

            expect(response).to have_http_status(:bad_request)
            expect(error_code).to eq('VA900')
            expect(response).to match_response_schema('errors')
          end
        end
      end
    end

    describe 'GET /v0/vaos/systems/:system_id/facilities' do
      context 'with a valid GET system facilities response' do
        it 'returns a 200 with the correct schema' do
          VCR.use_cassette('vaos/systems/get_system_facilities', match_requests_on: %i[method uri]) do
            get '/v0/vaos/systems/688/direct_scheduling_facilities', params: {
              parent_code: '688', type_of_care_id: '323'
            }

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_response_schema('vaos/system_facilities')
          end
        end
      end

      context 'when parent_code is missing' do
        it 'returns a 200 with the correct schema' do
          VCR.use_cassette('vaos/systems/get_system_facilities_noparent', match_requests_on: %i[method uri]) do
            get '/v0/vaos/systems/688/direct_scheduling_facilities', params: { type_of_care_id: '323' }

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_response_schema('vaos/system_facilities')
          end
        end
      end

      context 'when type_of_care_id is missing' do
        it 'returns an error message with the missing param' do
          VCR.use_cassette('vaos/systems/get_system_facilities', match_requests_on: %i[method uri]) do
            get '/v0/vaos/systems/688/direct_scheduling_facilities', params: { parent_code: '688' }

            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['errors'].first['detail'])
              .to eq('The required parameter "type_of_care_id", is missing')
          end
        end
      end
    end

    describe 'GET /v0/vaos/systems/:system_id/pact' do
      context 'with a valid GET system pact response' do
        it 'returns a 200 with the correct schema' do
          VCR.use_cassette('vaos/systems/get_system_pact', match_requests_on: %i[method uri]) do
            get '/v0/vaos/systems/688/pact'

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_response_schema('vaos/system_pact')
          end
        end
      end
    end
  end
end
