# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'

RSpec.describe 'sm', type: :request do
  context 'triage_teams' do
    it 'responds to GET #index', :vcr do
      allow_any_instance_of(ApplicationController).to receive(:authenticate).and_return(true)
      get '/v0/messaging/health/recipients'

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('triage_teams')
    end
  end
end
