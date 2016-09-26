# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

RSpec.describe 'Triage Teams Integration', type: :request do
  include SM::ClientHelpers

  it 'responds to GET #index' do
    allow_any_instance_of(ApplicationController).to receive(:authenticate).and_return(true)
    expect(SM::Client).to receive(:new).once.and_return(authenticated_client)

    VCR.use_cassette('sm/triage_teams/10616687/index') do
      get '/v0/messaging/health/recipients'
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('triage_teams')
  end
end
