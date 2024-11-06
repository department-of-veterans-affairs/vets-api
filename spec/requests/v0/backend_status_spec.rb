# frozen_string_literal: true

require 'rails_helper'
require 'support/pagerduty/services/spec_setup'

RSpec.describe 'V0::BackendStatus', type: :request do
  include SchemaMatchers

  let(:user) { build(:user, :loa3) }

  describe 'GET /v0/backend_statuses' do
    before { sign_in_as(user) }

    context 'happy path' do
      include_context 'simulating Redis caching of PagerDuty#get_services'

      it 'matches the backend_statuses schema', :aggregate_failures do
        get '/v0/backend_statuses'

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('backend_statuses')
      end

      it 'matches the backend_statuses schema when camel-inflected', :aggregate_failures do
        get '/v0/backend_statuses', headers: { 'X-Key-Inflection' => 'camel' }

        expect(response).to have_http_status(:ok)
        expect(response).to match_camelized_response_schema('backend_statuses')
      end
    end

    context 'when the PagerDuty API rate limit has been exceeded' do
      it 'returns a 429 error', :aggregate_failures do
        VCR.use_cassette('pagerduty/external_services/get_services_429', VCR::MATCH_EVERYTHING) do
          get '/v0/backend_statuses'

          body = JSON.parse(response.body)
          error = body['errors'].first

          expect(response.status).to be_a(Integer).and eq 429
          expect(error['code']).to be_a(String).and eq 'PAGERDUTY_429'
          expect(error['title']).to be_a(String).and eq 'Exceeded rate limit'
        end
      end
    end

    context 'when there are maintenance windows' do
      include_context 'simulating Redis caching of PagerDuty#get_services'

      let!(:maintenance_window) do
        create(:maintenance_window, start_time: 1.day.ago, end_time: 1.day.from_now)
      end

      it 'returns the maintenance windows', :aggregate_failures do
        get '/v0/backend_statuses'

        body = JSON.parse(response.body)
        maintenance_windows = body['data']['attributes']['maintenance_windows']

        expect(maintenance_windows).to be_an(Array)
        expect(maintenance_windows.first).to eq(maintenance_window.as_json(only: %i[id external_service start_time
                                                                                    end_time description]))
      end
    end
  end
end
