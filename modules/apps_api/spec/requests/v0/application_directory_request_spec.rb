# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Application Directory Endpoint', type: :request do
  describe '#get /services/apps/v0/directory' do
    it 'returns Okta Application Directory JSON' do
      VCR.use_cassette('okta/directories') do
        get '/services/apps/v0/directory'
        expect(response).to have_http_status(:success)
        JSON.parse(response.body)
      end
    end
    it 'returns a populated list of applications' do
      VCR.use_cassette('okta/directories') do
        get '/services/apps/v0/directory'
        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body).not_to be_empty
      end
    end
  end

  describe '#get /services/apps/v0/directory/scopes/:category' do
    it 'returns a populated list of health scopes' do
      VCR.use_cassette('okta/health-scopes') do
        get '/services/apps/v0/directory/scopes/Health'
        body = JSON.parse(response.body)
        expect(response).to have_http_status(:success)
        expect(body).not_to be_empty
        expect(body['data'][0]['name']).to eq('launch/patient')
      end
    end
    it 'returns a populated list of benefits scopes' do
      VCR.use_cassette('okta/benefits-scopes') do
        get '/services/apps/v0/directory/scopes/Benefits'
        body = JSON.parse(response.body)
        expect(response).to have_http_status(:success)
        expect(body).not_to be_empty
        expect(body['data'][0]['name']).to eq('claim.read')
      end
    end
    it 'returns a populated list of verification scopes' do
      VCR.use_cassette('okta/verification-scopes') do
        get '/services/apps/v0/directory/scopes/Verification'
        body = JSON.parse(response.body)
        expect(response).to have_http_status(:success)
        expect(body).not_to be_empty
        expect(body['data'][0]['name']).to eq('disability_rating.read')
      end
    end
  end
end
