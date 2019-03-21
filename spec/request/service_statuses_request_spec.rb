# frozen_string_literal: true

require 'rails_helper'
require 'support/pagerduty/services/spec_setup'

describe 'service_statuses', type: :request do
  include SchemaMatchers

  describe 'GET /v0/service_statuses' do
    let(:user) { build(:user, :loa3) }
    let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
    before(:each) { sign_in_as(user) }

    context 'happy path' do
      include_context 'simulating Redis caching of PagerDuty#get_services'

      it 'should match the service_statuses schema', :aggregate_failures do
        get '/v0/service_statuses'

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('service_statuses')
      end
    end

    context 'when the PagerDuty API rate limit has been exceeded' do
      it 'returns a 429 error', :aggregate_failures do
        VCR.use_cassette('pagerduty/external_services/get_services_429', VCR::MATCH_EVERYTHING) do
          get '/v0/service_statuses'

          body = JSON.parse(response.body)
          error = body.dig('errors').first

          expect(response.status).to eq 429
          expect(error['code']).to eq 'PAGERDUTY_429'
          expect(error['title']).to eq 'Exceeded rate limit'
        end
      end
    end
  end
end
