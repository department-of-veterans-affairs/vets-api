# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'NextOfKin', type: :request do
  describe 'GET /v0/next_of_kin' do
    it 'returns http success' do
      get '/v0/next_of_kin'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /v0/next_of_kin' do
    it 'returns http success' do
      post '/v0/next_of_kin'
      expect(response).to have_http_status(:success)
    end
  end
end
