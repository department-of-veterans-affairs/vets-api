# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'systems', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'with a loa1 user' do
    let(:user) { FactoryBot.create(:user, :loa1) }

    it 'returns a forbidden error' do
      skip 'VAOS V0 routes disabled'
      get '/vaos/v0/systems'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('You do not have access to online scheduling')
    end
  end

  context 'with a loa3 user' do
    let(:user) { build(:user, :mhv) }
    let(:error_code) { JSON.parse(response.body)['errors'].first['code'] }

    describe 'GET /vaos/v0/systems' do
      context 'with a valid GET systems response' do
        it 'returns a 200 with the correct schema' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/systems/get_systems', match_requests_on: %i[method path query]) do
            expect { get '/vaos/v0/systems' }
              .to trigger_statsd_increment('api.external_http_request.VAOS.success', times: 1, value: 1)

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_response_schema('vaos/systems')
          end
        end

        it 'returns a 200 with the correct camel-inflected schema' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/systems/get_systems', match_requests_on: %i[method path query]) do
            expect { get '/vaos/v0/systems', headers: inflection_header }
              .to trigger_statsd_increment('api.external_http_request.VAOS.success', times: 1, value: 1)

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_camelized_response_schema('vaos/systems')
          end
        end
      end

      context 'with a 403 response' do
        it 'returns a VAOS 403 error response' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/systems/get_systems_403', match_requests_on: %i[method path query]) do
            get '/vaos/v0/systems'

            expect(response).to have_http_status(:forbidden)
            expect(error_code).to eq('VAOS_403')
            expect(response).to match_response_schema('errors')
          end
        end

        it 'returns a VAOS 403 error response when camel-inflected' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/systems/get_systems_403', match_requests_on: %i[method path query]) do
            get '/vaos/v0/systems', headers: inflection_header

            expect(response).to have_http_status(:forbidden)
            expect(error_code).to eq('VAOS_403')
            expect(response).to match_camelized_response_schema('errors')
          end
        end
      end

      context 'with a timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it 'returns the default 504 error response' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/systems/get_systems', match_requests_on: %i[method path query]) do
            get '/vaos/v0/systems'
            expect(response).to have_http_status(:gateway_timeout)
            expect(error_code).to eq('504')
          end
        end
      end

      context 'with a 500 response' do
        it 'returns a VAOS 500 error response' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/systems/get_systems_500', match_requests_on: %i[method path query]) do
            get '/vaos/v0/systems'

            expect(response).to have_http_status(:bad_gateway)
            expect(error_code).to eq('VAOS_502')
            expect(response).to match_response_schema('errors')
          end
        end

        it 'returns a VAOS 500 error response when camel-inflected' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/systems/get_systems_500', match_requests_on: %i[method path query]) do
            get '/vaos/v0/systems', headers: inflection_header

            expect(response).to have_http_status(:bad_gateway)
            expect(error_code).to eq('VAOS_502')
            expect(response).to match_camelized_response_schema('errors')
          end
        end
      end

      context 'with an unmapped error' do
        it 'returns the default VA900 response' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/systems/get_systems_420', match_requests_on: %i[method path query]) do
            get '/vaos/v0/systems'

            expect(response).to have_http_status(:bad_request)
            expect(error_code).to eq('VA900')
            expect(response).to match_response_schema('errors')
          end
        end

        it 'returns the default VA900 response when camel-inflected' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/systems/get_systems_420', match_requests_on: %i[method path query]) do
            get '/vaos/v0/systems', headers: inflection_header

            expect(response).to have_http_status(:bad_request)
            expect(error_code).to eq('VA900')
            expect(response).to match_camelized_response_schema('errors')
          end
        end
      end
    end

    describe 'GET /vaos/v0/systems/:system_id/facilities' do
      context 'with a set of clinic ids' do
        it 'returns a 200 with the correct schema' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/systems/get_institutions', match_requests_on: %i[method path query]) do
            get '/vaos/v0/systems/442/clinic_institutions', params: { clinic_ids: [16, 90, 110, 192, 193] }

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_response_schema('vaos/system_institutions')
          end
        end

        it 'returns a 200 with the correct camel-inflected schema' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/systems/get_institutions', match_requests_on: %i[method path query]) do
            get '/vaos/v0/systems/442/clinic_institutions',
                params: { clinic_ids: [16, 90, 110, 192, 193] },
                headers: inflection_header

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_camelized_response_schema('vaos/system_institutions')
          end
        end
      end

      context 'with one clinic id' do
        it 'returns a 200 with the correct schema' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/systems/get_institutions_single', match_requests_on: %i[method path query]) do
            get '/vaos/v0/systems/442/clinic_institutions', params: { clinic_ids: 16 }

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_response_schema('vaos/system_institutions')
          end
        end

        it 'returns a 200 with the correct camel-inflected schema' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/systems/get_institutions_single', match_requests_on: %i[method path query]) do
            get '/vaos/v0/systems/442/clinic_institutions', params: { clinic_ids: 16 }, headers: inflection_header

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_camelized_response_schema('vaos/system_institutions')
          end
        end
      end
    end
  end
end
