# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Disability Rating API endpoint', type: :request, skip_emis: true do
  include SchemaMatchers

  let(:token) { 'token' }
  let(:jwt) do
    [{
      'ver' => 1,
      'jti' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
      'iss' => 'https://example.com/oauth2/default',
      'aud' => 'api://default',
      'iat' => Time.current.utc.to_i,
      'exp' => Time.current.utc.to_i + 3600,
      'cid' => '0oa1c01m77heEXUZt2p7',
      'uid' => '00u1zlqhuo3yLa2Xs2p7',
      'scp' => %w[profile email openid disability_rating.read],
      'sub' => 'ae9ff5f4e4b741389904087d94cd19b2'
    }, {
      'kid' => '1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU',
      'alg' => 'RS256'
    }]
  end
  let(:auth_header) { { 'Authorization' => "Bearer #{token}" } }
  let(:user) { build(:user, :loa3) }

  before(:each) do
    allow(JWT).to receive(:decode).and_return(jwt)
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  context 'with valid emis responses' do
    it 'should return the current users service history with one episode' do
      with_okta_configured do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
          get '/services/veteran_verification/v0/disability_rating', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('disability_rating_response')
        end
      end
    end
  end

  context 'with a 500 response' do
    it 'should return a bad gateway response' do
      with_okta_configured do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_500') do
          get '/services/veteran_verification/v0/disability_rating', nil, auth_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end
  end

  context 'with a 403 unauthorized response' do
    it 'should return a not authorized response' do
      with_okta_configured do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_403') do
          get '/services/veteran_verification/v0/disability_rating', nil, auth_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end
  end

  context 'with a generic 400 response' do
    it 'should return a bad request response' do
      with_okta_configured do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_400') do
          get '/services/veteran_verification/v0/disability_rating', nil, auth_header
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end
  end
end
