# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Total Disability Rating API endpoint', type: :request do

  let(:token) { 'token' }
  let(:auth_header) { { 'Authorization' => "Bearer #{token}", 'Accept' => '*/*' } }
  let(:user) { create(:evss_user) }
  let(:user) { build(:disabilities_compensation_user, ssn: '796126777') }

  context 'with valid bgs responses' do
    it 'returns the current users total service related disability rating' do
      with_okta_configured do
        VCR.use_cassette('bgs/rating_web_service/rating_data') do
          get '/services/veteran_verification/v0/total_disability_rating', params: nil, headers: auth_header
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
