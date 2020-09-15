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
end
