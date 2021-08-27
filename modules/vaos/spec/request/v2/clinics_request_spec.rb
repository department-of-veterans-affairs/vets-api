# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'clinics', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'with a loa3 user' do
    let(:user) { build(:user, :mhv) }

    describe 'GET facility clinics' do
      context 'on successful query for clinics given service type' do
        it 'returns a list of clinics' do
          VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200', match_requests_on: %i[method uri]) do
            allow(Rails.logger).to receive(:info).at_least(:once)
            get '/vaos/v2/locations/983/clinics?clinical_service=audiology', headers: inflection_header
            expect(Rails.logger).to have_received(:info).with('Clinic names returned',
                                                              ['CHY C&P AUDIO', 'FTC C&P AUDIO BEV',
                                                               'CHY C&P AUDIO JAN', 'CHY AUDIOLOGY',
                                                               'WHT AUDIO VAR2', 'TOR C&P LORI',
                                                               'WHT HEARING AID LORI']).at_least(:once)
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
          VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200', match_requests_on: %i[method uri]) do
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
          VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200', match_requests_on: %i[method uri]) do
            get '/vaos/v2/locations/983/clinics?clinic_ids[]=570&clinic_ids[]=945', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to match_camelized_schema('vaos/v2/clinics', { strict: false })
            expect(JSON.parse(response.body)['data'].size).to eq(2)
          end
        end
      end

      context 'on successful query for clinics given an array with a single clinic id' do
        it 'returns a single clinic' do
          VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200', match_requests_on: %i[method uri]) do
            get '/vaos/v2/locations/983/clinics?clinic_ids[]=570', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to match_camelized_schema('vaos/v2/clinics', { strict: false })
            expect(JSON.parse(response.body)['data'].size).to eq(1)
          end
        end
      end

      context 'on successful query for clinics given an array with a single clinic id when camel-inflected' do
        it 'returns a single clinic' do
          VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200', match_requests_on: %i[method uri]) do
            get '/vaos/v2/locations/983/clinics?clinic_ids[]=570', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['data'].size).to eq(1)
            expect(response.body).to match_camelized_schema('vaos/v2/clinics')
          end
        end
      end

      context 'on sending a bad request to the VAOS Service' do
        it 'returns a 400 http status' do
          VCR.use_cassette('vaos/v2/systems/get_facility_clinics_400', match_requests_on: %i[method uri]) do
            get '/vaos/v2/locations/983/clinics?clinic_ids[]=570&clinical_service=audiology'
            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_400')
          end
        end
      end
    end
  end
end
