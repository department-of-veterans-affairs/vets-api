# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Connected Applications API endpoint', type: :request do
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    user[:uuid] = '00u2fqgvbyT23TZNm2p7'
    Session.create(uuid: '00u2fqgvbyT23TZNm2p7', token: token)
    User.create(user)
  end

  context 'with valid response from okta' do
    it 'should return list of grants by app' do
      with_settings(
        Settings.oidc,
        auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/oauth-authorization-server',
        issuer: 'https://example.com/oauth2/default',
        base_api_url: 'https://example.com/api/v1/',
        base_api_token: 'token'
      ) do
        VCR.use_cassette('okta/grants') do
          get '/v0/profile/connected_applications', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data'][0]['id']).to eq('0oa2ey2m6kEL2897N2p7')
        end
      end
    end

    it 'should delete all the grants by app' do
      with_settings(
        Settings.oidc,
        auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/oauth-authorization-server',
        issuer: 'https://example.com/oauth2/default',
        base_api_url: 'https://example.com/api/v1/',
        base_api_token: 'token'
      ) do
        VCR.use_cassette('okta/delete_grants') do
          delete '/v0/profile/connected_applications/0oa2ey2m6kEL2897N2p7', nil, auth_header
          expect(response).to have_http_status(:no_content)
        end
      end
    end
  end
end
