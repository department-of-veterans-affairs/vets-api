# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Disability Rating Mock API endpoint', type: :request do
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
  let(:auth_header) { { 'Authorization' => "Bearer #{token}", 'Accept' => '*/*' } }
  let(:user) { create(:openid_user, identity_attrs: build(:user_identity_attrs, :loa3, ssn: '796126777')) }

  before do
    allow(JWT).to receive(:decode).and_return(jwt)
    Session.create(uuid: user.uuid, token:)
    allow(Settings.vet_verification).to receive(:mock_bgs).and_return(true)
    allow(Settings.vet_verification).to receive(:mock_bgs_url).and_return('https://blue.qa.lighthouse.va.gov/mock-bgs/v0')
  end

  context 'with valid mock bgs responses' do
    it 'returns all the current user disability ratings and overall service connected combined degree' do
      with_okta_configured do
        VCR.use_cassette('bgs/rating_web_service/mock_rating_data') do
          get '/services/veteran_verification/v0/disability_rating', params: nil, headers: auth_header
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('disability_rating_response')
        end
      end
    end
  end
end
