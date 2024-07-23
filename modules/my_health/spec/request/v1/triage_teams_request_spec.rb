# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'Triage Teams Integration', type: :request do
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
      get '/my_health/v1/messaging/recipients'
    end

    after do
      VCR.eject_cassette
    end

    include_examples 'for user account level', message: 'You do not have access to messaging'
  end

  context 'when authorized' do
    before do
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end

    it 'responds to GET #index' do
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_triage_team_recipients') do
        get '/my_health/v1/messaging/recipients'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('triage_teams')
    end

    it 'responds to GET #index when camel-inflected' do
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_triage_team_recipients') do
        get '/my_health/v1/messaging/recipients', headers: { 'X-Key-Inflection' => 'camel' }
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('triage_teams')
    end
  end
end
