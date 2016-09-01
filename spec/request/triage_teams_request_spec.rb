# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Triage Teams Integration', type: :request do
  let(:id) { '10616687' }

  before(:each) do
    VCR.use_cassette('triage_teams/10616687/index') do
      get '/v0/triage_teams', id: id
    end
  end

  it 'responds to GET #index' do
    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('triage_teams')
  end
end
