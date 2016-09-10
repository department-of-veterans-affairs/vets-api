# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Triage Teams Integration', type: :request do
  let(:user_id) { ENV['MHV_SM_USER_ID'] }

  before(:each) do
    VCR.use_cassette("triage_teams/#{user_id}/index") do
      get '/v0/messaging/health/recipients'
    end
  end

  it 'responds to GET #index' do
    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('triage_teams')
  end
end
