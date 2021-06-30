# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'discovery', type: :request do
  include JsonSchemaMatchers
  describe 'GET /mobile' do
    context 'when the mobile_api flipper feature is enabled' do
      let(:expected_body) do
        {
          'data' => {
            'attributes' => {
              'message' => 'Welcome to the mobile API'
            }
          }
        }
      end
    end

    context 'when the mobile_api flipper feature is disabled' do
      before { Flipper.disable('mobile_api') }

      it 'returns a 404' do
        get '/mobile'

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /discovery' do
    let(:response_attributes) { response.parsed_body.dig('data', 'attributes') }

    context 'when no maintenance windows are active' do
      before { get '/mobile/discovery', headers: { 'X-Key-Inflection' => 'camel' } }

      it 'has a auth_base_url' do
        expect(response_attributes['authBaseUrl']).to eq('https://sqa.fed.eauth.va.gov/oauthe/sps/oauth/oauth20/')
      end

      it 'has a api_root_url' do
        expect(response_attributes['apiRootUrl']).to eq('https://dev.va.gov/mobile')
      end

      it 'lets the app know the minimum_version supported' do
        expect(response_attributes['minimumVersion']).to eq('1.0.0')
      end

      it 'has the expected web views' do
        expect(response_attributes['webViews']).to eq(
          {
            'coronaFaq' => 'https://www.va.gov/coronavirus-veteran-frequently-asked-questions',
            'facilityLocator' => 'https://www.va.gov/find-locations'
          }
        )
      end

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('discovery')
      end

      it 'returns an empty array of affected services' do
        expect(response_attributes['maintenanceWindows']).to eq([])
      end
    end

    context 'when a maintenance with many dependent services is active' do
      before do
        Timecop.freeze('2021-05-25T23:33:39Z')
        FactoryBot.create(:mobile_maintenance_evss)
        FactoryBot.create(:mobile_maintenance_mpi)
        get '/mobile/discovery', headers: { 'X-Key-Inflection' => 'camel' }
      end

      after { Timecop.return }

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('discovery')
      end

      it 'returns an array of the affected services' do
        expect(response_attributes['maintenanceWindows']).to eq([
                                                                  {
                                                                    'service' => 'claims',
                                                                    'startTime' => '2021-05-25T21:33:39.000Z',
                                                                    'endTime' => '2021-05-26T01:45:00.000Z',
                                                                    'description' => 'evss is down, mpi is down'
                                                                  },
                                                                  {
                                                                    'service' => 'direct_deposit_benefits',
                                                                    'startTime' => '2021-05-25T21:33:39.000Z',
                                                                    'endTime' => '2021-05-26T01:45:00.000Z',
                                                                    'description' => 'evss is down, mpi is down'
                                                                  },
                                                                  {
                                                                    'service' => 'letters_and_documents',
                                                                    'startTime' => '2021-05-25T21:33:39.000Z',
                                                                    'endTime' => '2021-05-26T01:45:00.000Z',
                                                                    'description' => 'evss is down, mpi is down'
                                                                  },
                                                                  {
                                                                    'service' => 'auth_dslogon',
                                                                    'startTime' => '2021-05-25T23:33:39.000Z',
                                                                    'endTime' => '2021-05-26T01:45:00.000Z',
                                                                    'description' => 'mpi is down'
                                                                  },
                                                                  {
                                                                    'service' => 'auth_idme',
                                                                    'startTime' => '2021-05-25T23:33:39.000Z',
                                                                    'endTime' => '2021-05-26T01:45:00.000Z',
                                                                    'description' => 'mpi is down'
                                                                  },
                                                                  {
                                                                    'service' => 'auth_mhv',
                                                                    'startTime' => '2021-05-25T23:33:39.000Z',
                                                                    'endTime' => '2021-05-26T01:45:00.000Z',
                                                                    'description' => 'mpi is down'
                                                                  }
                                                                ])
      end
    end
  end
end
