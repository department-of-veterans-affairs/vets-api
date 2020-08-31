# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Application Directory Endpoint', type: :request do
  describe '#get /services/apps/v0/directory' do
    it 'returns Okta Application Directory JSON' do
      get '/services/apps/v0/directory'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end
end
