# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

RSpec.describe 'Triage Teams Integration', type: :request do
  include SM::ClientHelpers

  let(:current_user) { build(:mhv_user) }

  it 'responds to GET #index' do
    allow(SM::Client).to receive(:new).and_return(authenticated_client)
    use_authenticated_current_user(current_user: current_user)

    VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_triage_team_recipients') do
      get '/v0/messaging/health/recipients'
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('triage_teams')
  end
end
