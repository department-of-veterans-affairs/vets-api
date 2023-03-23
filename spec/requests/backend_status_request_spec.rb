# frozen_string_literal: true

require 'rails_helper'
require 'support/pagerduty/services/spec_setup'

RSpec.describe 'Backend Status' do
  include SchemaMatchers

  let(:user) { build(:user, :loa3) }

  describe '#show' do
    let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
    let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
    let(:tz) { ActiveSupport::TimeZone.new(EVSS::GiBillStatus::Service::OPERATING_ZONE) }
    let(:offline_saturday) { tz.parse('17th Mar 2018 19:00:01') }
    let(:online_weekday) { tz.parse('24th Jan 2018 06:00:00') }

    before do
      Session.create(uuid: user.uuid, token:)
      User.create(user)
    end

    it 'responds 200' do
      get v0_backend_status_url('gibs'), params: nil, headers: auth_header
      expect(response).to have_http_status(:ok)
    end

    context 'for the gibs service' do
      context 'during offline hours on saturday' do
        before { Timecop.freeze(offline_saturday) }

        after { Timecop.return }

        it 'indicates the service is unavailable' do
          get v0_backend_status_url('gibs'), params: nil, headers: auth_header
          json = JSON.parse(response.body)

          expect(json['data']['attributes']['is_available']).to eq(false)
          expect(json['data']['attributes']['name']).to be_a(String).and eq('gibs')
        end

        it 'returns 0 as number of seconds until next downtime' do
          get v0_backend_status_url('gibs'), params: nil, headers: auth_header
          json = JSON.parse(response.body)
          expect(json['data']['attributes']['uptime_remaining']).to be_a(Integer).and eq(0)
        end
      end

      context 'during online hours on weekday' do
        before { Timecop.freeze(online_weekday) }

        after { Timecop.return }

        it 'indicates the service is available' do
          get v0_backend_status_url('gibs'), params: nil, headers: auth_header
          json = JSON.parse(response.body)
          expect(json['data']['attributes']['is_available']).to eq(true)
          expect(json['data']['attributes']['name']).to be_a(String).and eq('gibs')
        end

        it 'returns number of seconds until next downtime' do
          get v0_backend_status_url('gibs'), params: nil, headers: auth_header
          json = JSON.parse(response.body)
          expect(json['data']['attributes']['uptime_remaining']).to be_a(Integer).and eq(57_600)
        end
      end
    end

    context 'for non-gibs service' do
      it 'always indicates the service is available' do
        get v0_backend_status_url('hca'), params: nil, headers: auth_header
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['is_available']).to eq(true)
        expect(json['data']['attributes']['name']).to be_a(String).and eq('hca')
      end

      it 'always returns 0 as number of seconds until next downtime' do
        get v0_backend_status_url('hca'), params: nil, headers: auth_header
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['uptime_remaining']).to be_a(Integer).and eq(0)
      end
    end
  end

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
  end
end
