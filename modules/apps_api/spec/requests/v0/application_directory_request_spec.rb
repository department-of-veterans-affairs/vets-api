# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Application Directory Endpoint', type: :request do
  describe '#get /services/apps/v0/directory' do
    it 'returns a populated list of applications' do
      get '/services/apps/v0/directory'
      body = JSON.parse(response.body)
      expect(body).not_to be_empty
    end
  end

  describe '#get /services/apps/v0/directory/:name' do
    it 'returns a single application' do
      get '/services/apps/v0/directory/Apple%20Health'
      body = JSON.parse(response.body)
      expect(body.length).to be(1)
    end
    it 'returns an app when passing the :name param' do
      get '/services/apps/v0/directory/iBlueButton'
      body = JSON.parse(response.body)
      expect(body).not_to be_empty
    end
  end

  describe '#get /services/apps/v0/directory/scopes/:category' do
    it 'returns a populated list of health scopes' do
      VCR.use_cassette('okta/health-scopes', match_requests_on: %i[method path]) do
        get '/services/apps/v0/directory/scopes/Health'
        body = JSON.parse(response.body)
        expect(response).to have_http_status(:success)
        expect(body).not_to be_empty
        expect(body['data'][0]['name']).to eq('launch/patient')
      end
    end
    it 'returns a populated list of benefits scopes' do
      VCR.use_cassette('okta/benefits-scopes', match_requests_on: %i[method path]) do
        get '/services/apps/v0/directory/scopes/Benefits'
        body = JSON.parse(response.body)
        expect(response).to have_http_status(:success)
        expect(body).not_to be_empty
        expect(body['data'][0]['name']).to eq('claim.read')
      end
    end
    it 'returns a populated list of verification scopes' do
      VCR.use_cassette('okta/verification-scopes', match_requests_on: %i[method path]) do
        get '/services/apps/v0/directory/scopes/Verification'
        body = JSON.parse(response.body)
        expect(response).to have_http_status(:success)
        expect(body).not_to be_empty
        expect(body['data'][0]['name']).to eq('disability_rating.read')
      end
    end
    it 'returns an empty list when given an unknown category' do
      VCR.use_cassette('okta/verification-scopes', match_requests_on: %i[method path]) do
        get '/services/apps/v0/directory/scopes/unknown_category'
        expect(response).to have_http_status(:no_content)
      end
    end
    it '204s when given a null category' do
      VCR.use_cassette('okta/verification-scopes', match_requests_on: %i[method path]) do
        get '/services/apps/v0/directory/scopes'
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
