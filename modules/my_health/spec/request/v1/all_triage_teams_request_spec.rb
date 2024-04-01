# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'All Triage Teams Integration', type: :request do
  include SchemaMatchers

  let(:current_user) { build(:user, :mhv, va_patient:) }

  before do
    Flipper.enable(:mhv_sm_session_policy)
    Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
    sign_in_as(current_user)
  end

  after do
    Flipper.disable(:mhv_sm_session_policy)
    Timecop.return
  end

  context 'when authorized' do
    before do
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end

    it 'responds to GET #index' do
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients') do
        get '/my_health/v1/messaging/allrecipients'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('all_triage_teams')
    end

    it 'responds to GET #index when camel-inflected' do
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients') do
        get '/my_health/v1/messaging/allrecipients', headers: { 'X-Key-Inflection' => 'camel' }
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('all_triage_teams')
    end
  end
end
