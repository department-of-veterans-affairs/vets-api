# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::Messaging::Allrecipients', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:current_user) { build(:user, :mhv) }

  before do
    sign_in_as(current_user)
    Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
  end

  after do
    Timecop.return
  end

  context 'when NOT authorized' do
    before do
      VCR.insert_cassette('sm_client/session_error')
      get '/my_health/v1/messaging/allrecipients'
    end

    after do
      VCR.eject_cassette
    end

    include_examples 'for user account level', message: 'You do not have access to messaging'
  end

  context 'when facilities api call fails' do
    before do
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end
  end

  context 'when authorized' do
    before do
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end

    it 'replaces missing health care system names in non-prod environments' do
      VCR.use_cassette('sm_client/triage_teams/gets_all_triage_team_recipients_missing_system_names') do
        get '/my_health/v1/messaging/allrecipients'
      end

      expect(response).to be_successful
      resp_body = JSON.parse(response.body)
      expect(resp_body['data'][0]['attributes']['station_number']).to eq('552')
    end

    it 'replaces missing health care system ids in prod environment' do
      VCR.use_cassette('sm_client/triage_teams/gets_all_triage_team_recipients_vha_612') do
        get '/my_health/v1/messaging/allrecipients'
      end

      expect(response).to be_successful
      resp_body = JSON.parse(response.body)
      expect(resp_body['data'][0]['attributes']['station_number']).to eq('612A4')
    end

    it 'replaces health care system names for hardcoded stations' do
      # rubocop:disable Layout/LineLength
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients_include_complex_teams') do
        get '/my_health/v1/messaging/allrecipients'
      end
      # rubocop:enable Layout/LineLength
      expect(response).to be_successful
      resp_body = JSON.parse(response.body)
      resp_body['data'].each do |team|
        station_number = team['attributes']['station_number']
        expected_name = MyHealth::FacilitiesHelper::COMPLICATED_SYSTEMS[station_number]
        expect(team['attributes']['health_care_system_name']).to eq(expected_name) if expected_name
      end
    end

    it 'does not replace existing health care system names but does replace non-prod station_numbers' do
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients') do
        get '/my_health/v1/messaging/allrecipients'
      end

      expect(response).to be_successful
      resp_body = JSON.parse(response.body)
      expect(resp_body['data'][0]['attributes']['station_number']).to eq('552')
    end

    it 'responds to GET #index' do
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients') do
        get '/my_health/v1/messaging/allrecipients'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('my_health/messaging/v1/all_triage_teams')
    end

    it 'responds to GET #index when camel-inflected' do
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients') do
        get '/my_health/v1/messaging/allrecipients', headers: { 'X-Key-Inflection' => 'camel' }
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('my_health/messaging/v1/all_triage_teams')
    end

    it 'when resource is blank returns 404 RecordNotFound' do
      allow(StatsD).to receive(:increment)
      allow_any_instance_of(SM::Client).to receive(:get_all_triage_teams).and_return(nil)

      get '/my_health/v1/messaging/allrecipients'

      expect(StatsD).to have_received(:increment).with('api.my_health.all_triage_teams.fail')
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('Triage teams for user ID')
    end
  end

  context 'with requires_oh flag enabled' do
    it 'responds to GET #index with requires_oh flipper' do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_secure_messaging_cerner_pilot, anything)
        .and_return(true)

      VCR.use_cassette('sm_client/session_require_oh') do
        VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients_require_oh') do
          get '/my_health/v1/messaging/allrecipients'
        end
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('my_health/messaging/v1/all_triage_teams')
    end
  end
end
