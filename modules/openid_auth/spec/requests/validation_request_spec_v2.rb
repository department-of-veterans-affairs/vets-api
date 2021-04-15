# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Validated Token API endpoint', type: :request, skip_emis: true do
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
      'icn' => '73806470379396828',
      'scp' => %w[profile email openid veteran_status.read],
      'sub' => 'ae9ff5f4e4b741389904087d94cd19b2'
    }, {
      'kid' => '1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU',
      'alg' => 'RS256'
    }]
  end
  let(:invalid_issuer_jwt) do
    [{
      'ver' => 1,
      'jti' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
      'iss' => 'https://invalid-issuer.org/oauth2/default',
      'aud' => 'api://default',
      'iat' => Time.current.utc.to_i,
      'exp' => Time.current.utc.to_i + 3600,
      'cid' => '0oa1c01m77heEXUZt2p7',
      'uid' => '00u1zlqhuo3yLa2Xs2p7',
      'icn' => '73806470379396828',
      'scp' => %w[profile email openid veteran_status.read],
      'sub' => 'ae9ff5f4e4b741389904087d94cd19b2'
    }, {
      'kid' => '1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU',
      'alg' => 'RS256'
    }]
  end
  let(:client_credentials_jwt) do
    [
      {
        'ver' => 1,
        'jti' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
        'iss' => 'https://example.com/oauth2/default',
        'aud' => 'api://default',
        'iat' => Time.current.utc.to_i,
        'exp' => Time.current.utc.to_i + 3600,
        'cid' => '0oa1c01m77heEXUZt2p7',
        'uid' => '00u1zlqhuo3yLa2Xs2p7',
        'scp' => %w[profile email launch/patient],
        'sub' => '0oa1c01m77heEXUZt2p7'
      },
      {
        'kid' => '1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU',
        'alg' => 'RS256'
      }
    ]
  end
  let(:launch_response) do
    instance_double(RestClient::Response,
                    code: 200,
                    body: { launch: '73806470379396828' }.to_json)
  end
  let(:failed_launch_response) do
    instance_double(RestClient::Response,
                    code: 401)
  end
  let(:json_api_response) do
    {
      'data' => {
        'id' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
        'type' => 'validated_token',
        'attributes' => {
          'ver' => 1,
          'jti' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
          'iss' => 'https://example.com/oauth2/default',
          'aud' => 'api://default',
          'iat' => 1_541_453_784,
          'exp' => 1_541_457_384,
          'cid' => '0oa1c01m77heEXUZt2p7',
          'uid' => '00u1zlqhuo3yLa2Xs2p7',
          'scp' => [
            'profile',
            'email',
            'openid',
            'veteran_status.read'
          ],
          'sub' => 'ae9ff5f4e4b741389904087d94cd19b2',
          'act' => {
            'icn' => '73806470379396828',
            'type' => 'patient'
          },
          'launch' => {
            'icn' => '73806470379396828'
          }
        }
      }
    }
  end
  let(:json_cc_api_response) do
    {
      'data' => {
        'id' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
        'type' => 'validated_token',
        'attributes' => {
          'ver' => 1,
          'jti' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
          'iss' => 'https://example.com/oauth2/default',
          'aud' => 'api://default',
          'iat' => 1_541_453_784,
          'exp' => 1_541_457_384,
          'cid' => '0oa1c01m77heEXUZt2p7',
          'uid' => '00u1zlqhuo3yLa2Xs2p7',
          'scp' => [
            'profile',
            'email',
            'openid',
            'veteran_status.read'
          ],
          'sub' => 'ae9ff5f4e4b741389904087d94cd19b2',
          'act' => {
            'icn' => nil,
            'type' => 'system'
          },
          'launch' => {
            'patient' => '73806470379396828'
          }
        }
      }
    }
  end
  let(:auth_header) { { 'Authorization' => "Bearer #{token}" } }
  let(:user) { OpenidUser.new(build(:user_identity_attrs, :loa3)) }

  context 'with valid responses' do
    before do
      allow(JWT).to receive(:decode).and_return(jwt)
      Session.create(token: token, uuid: user.uuid)
      user.save
    end

    it 'v2 POST returns invalid audience for strict=true, aud=nil' do
      with_okta_configured do
        post '/internal/auth/v2/validation', params: { strict: 'true' }, headers: auth_header
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq '401'
        expect(JSON.parse(response.body)['errors'].first['detail']).to eq 'Invalid audience'
      end
    end

    it 'v2 POST returns invalid audience for strict=true, and aud not in list' do
      with_okta_configured do
        post '/internal/auth/v2/validation', params: { strict: 'true', aud: %w[http://test foo://bar] },
                                             headers: auth_header
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq '401'
        expect(JSON.parse(response.body)['errors'].first['detail']).to eq 'Invalid audience'
      end
    end

    it 'v2 POST returns invalid audience for invalid strict value' do
      with_okta_configured do
        post '/internal/auth/v2/validation', params: { strict: 'foo', aud: 'http://test' }, headers: auth_header
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq '401'
        expect(JSON.parse(response.body)['errors'].first['detail']).to eq 'Invalid strict value'
      end
    end

    it 'v2 POST returns valid response for strict=false, and aud not in list' do
      with_okta_configured do
        post '/internal/auth/v2/validation', params: { strict: 'false', aud: 'http://test' },
                                             headers: auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
      end
    end

    it 'v2 POST returns valid response for strict=true, and aud is in list' do
      with_okta_configured do
        post '/internal/auth/v2/validation', params: { strict: 'true', aud: 'api://default' },
                                             headers: auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
      end
    end

    it 'v2 POST returns true if the user is a veteran' do
      with_okta_configured do
        post '/internal/auth/v2/validation', params: nil, headers: auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes'].keys).to eq(json_api_response['data']['attributes'].keys)
      end
    end
  end

  context 'when token is unauthorized' do
    it 'v2 POST returns an unauthorized for bad token', :aggregate_failures do
      with_okta_configured do
        post '/internal/auth/v2/validation', params: nil, headers: auth_header

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq '401'
      end
    end
  end

  context 'when token is from invalid issuer' do
    before do
      allow(JWT).to receive(:decode).and_return(invalid_issuer_jwt)
    end

    it 'v2 POST returns an unauthorized for bad token', :aggregate_failures do
      with_okta_configured do
        post '/internal/auth/v2/validation', params: nil, headers: auth_header

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq '401'
        expect(JSON.parse(response.body)['errors'].first['detail']).to eq 'Invalid issuer'
      end
    end
  end

  context 'when a response is invalid' do
    before do
      allow(JWT).to receive(:decode).and_return(jwt)
      Session.create(uuid: user.uuid, token: token)
      user.save
    end

    it 'v2 returns a server error if serialization fails', :aggregate_failures do
      allow_any_instance_of(OpenidAuth::ValidationSerializer).to receive(:attributes).and_raise(StandardError, 'random')
      with_okta_configured do
        post '/internal/auth/v1/validation', params: nil, headers: auth_header

        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq '500'
      end
    end

    it 'v2 POST returns a not found when va profile returns not found', :aggregate_failures do
      allow_any_instance_of(OpenidUser).to receive(:va_profile_status).and_return('NOT_FOUND')
      with_okta_configured do
        post '/internal/auth/v1/validation', params: nil, headers: auth_header

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq '404'
      end
    end

    it 'v2 POST returns a server error when va profile returns server error', :aggregate_failures do
      allow_any_instance_of(OpenidUser).to receive(:va_profile_status).and_return('SERVER_ERROR')
      with_okta_configured do
        post '/internal/auth/v1/validation', params: nil, headers: auth_header

        expect(response).to have_http_status(:bad_gateway)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq '502'
      end
    end
  end

  context 'with client credentials jwt' do
    before do
      allow(JWT).to receive(:decode).and_return(client_credentials_jwt)
      allow(RestClient).to receive(:get).and_return(launch_response)
    end

    it 'v2 POST returns true if the user is a veteran' do
      with_okta_configured do
        post '/internal/auth/v2/validation', params: nil, headers: auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes'].keys)
          .to eq(json_cc_api_response['data']['attributes'].keys)
        expect(JSON.parse(response.body)['data']['attributes']['launch']['patient']).to eq('73806470379396828')
      end
    end
  end

  context 'with client credentials jwt and failed launch lookup' do
    before do
      allow(JWT).to receive(:decode).and_return(client_credentials_jwt)
      allow(RestClient).to receive(:get).and_return(failed_launch_response)
    end

    it 'v2 POST returns true if the user is a veteran' do
      with_okta_configured do
        post '/internal/auth/v2/validation', params: nil, headers: auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes'].keys)
          .to eq(json_cc_api_response['data']['attributes'].keys)
        expect(JSON.parse(response.body)['data']['attributes']['launch']['patient']).to eq(nil)
      end
    end
  end
end
