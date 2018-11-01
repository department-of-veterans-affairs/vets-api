# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Veteran Status API endpoint', type: :request, skip_emis: true do
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
      'scp' => %w[profile email openid veteran_status.read],
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
    it 'should return true if the user is a veteran' do
      with_okta_configured do
        VCR.use_cassette('emis/get_veteran_status/valid') do
          get '/services/veteran_verification/v0/status', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['veteran_status']).to eq('confirmed')
        end
      end
    end

    it 'should return not_confirmed if the user is not a veteran' do
      with_okta_configured do
        VCR.use_cassette('emis/get_veteran_status/valid_non_veteran') do
          get '/services/veteran_verification/v0/status', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['veteran_status']).to eq('not confirmed')
        end
      end
    end
  end

  context 'when emis response is invalid' do
    before do
      allow(EMISRedis::MilitaryInformation).to receive_message_chain(:for_user, :veteran_status) { nil }
    end

    it 'should match the errors schema', :aggregate_failures do
      with_okta_configured do
        get '/services/veteran_verification/v0/status', nil, auth_header

        expect(response).to have_http_status(:bad_gateway)
        expect(response).to match_response_schema('errors')
        expect(JSON.parse(response.body)['errors'].first['code']).to eq 'EMIS_STATUS502'
      end
    end
  end
end
