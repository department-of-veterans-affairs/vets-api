# frozen_string_literal: true

require 'rails_helper'
require 'webmock'
require 'lighthouse/charon/response'

RSpec.describe 'Validated Token API endpoint', type: :request, skip_emis: true do
  include SchemaMatchers

  let(:token) { 'token' }
  let(:hashed_token) { '3c469e9d6c5875d37a43f353d4f88e61fcf812c66eee3457465a40b0da4153e0' }
  let(:static_token) { '123456789' }
  let(:opaque_token) { 'abcde12345abcde12345' }
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
  let(:client_credentials_launch_jwt) do
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
        'scp' => %w[launch],
        'sub' => '0oa1c01m77heEXUZt2p7'
      },
      {
        'kid' => '1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU',
        'alg' => 'RS256'
      }
    ]
  end
  let(:jwt_charon) do
    [
      {
        'ver' => 1,
        'last_login_type' => 'ssoi',
        'jti' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
        'iss' => 'https://example.com/oauth2/default',
        'aud' => 'https://example.com/xxxxxxservices/xxxxx',
        'iat' => Time.current.utc.to_i,
        'exp' => Time.current.utc.to_i + 3600,
        'cid' => '0oa1c01m77heEXUZt2p7',
        'uid' => '00u1zlqhuo3yLa2Xs2p7',
        'scp' => %w[profile email openid launch],
        'sub' => 'ae9ff5f4e4b741389904087d94cd19b2'
      },
      {
        'kid' => '1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU',
        'alg' => 'RS256'
      }
    ]
  end

  let(:issued_static_response) do
    instance_double(RestClient::Response,
                    code: 200,
                    body: { static: true, aud: 'https://example.com/xxxxxxservices/xxxxx', icn: '1234678',
                            scopes: 'patient/Patient.read launch/patient' }.to_json)
  end

  let(:issued_ssoi_response) do
    instance_double(RestClient::Response,
                    code: 200,
                    body: { static: false, proxy: 'https://example.com',
                            aud: 'https://example.com/xxxxxxservices/xxxxx' }.to_json)
  end

  let(:openid_response) do
    instance_double(RestClient::Response,
                    code: 200,
                    body: { 'issuer': 'https://example.com/issuer',
                            'authorization_endpoint': 'https://example.com/authorization',
                            'token_endpoint': 'https://example.com/token',
                            'userinfo_endpoint': 'https://example.com/userinfo',
                            'introspection_endpoint': 'https://example.com/introspect',
                            'revocation_endpoint': 'https://example.com/revoke' }.to_json)
  end

  let(:ssoi_introspect_response) do
    instance_double(RestClient::Response,
                    code: 200,
                    body: {
                      'type': 'ssoi',
                      'static': false,
                      'scope': 'openid profile patient/Medication.read offline_access',
                      'expires_in': 3600,
                      'fediamMVIICN': '555',
                      'npi': 'sample-npi',
                      'fediamsecid': '1013031911',
                      'fediamVISTAID': '508|12345^PN^508^USVHA|A,509|23456^PN^509^USVHA|A,510|34567^PN^510^USVHA|A',
                      'iat': 1_568_040_790,
                      'exp': 1_568_041_690,
                      'sub': '1013031911',
                      'fediamassurLevel': '3',
                      'fediamissuer': 'VA_SSOi_IDP',
                      'client_id': 'ampl_gui'
                    }.to_json)
  end

  let(:launch_response) do
    instance_double(RestClient::Response,
                    code: 200,
                    body: { launch: '73806470379396828' }.to_json)
  end
  let(:launch_with_sta3n_response) do
    instance_double(RestClient::Response,
                    code: 200,
                    body: { launch: 'eyAicGF0aWVudCI6ICIxMjM0NSIsICJzdGEzbiI6ICI0NTYiIH0K' }.to_json)
  end
  let(:launch_with_wrong_sta3n_response) do
    instance_double(RestClient::Response,
                    code: 200,
                    body: { launch: 'eyJpY24iOiIxMjM0NDUiLCAic3RhM24iOiI3ODkifQo=' }.to_json)
  end
  let(:failed_launch_response) do
    instance_double(RestClient::Response,
                    code: 401)
  end
  let(:bad_launch_response) do
    instance_double(RestClient::Response,
                    code: 503)
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
  let(:json_api_response_vista_id) do
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
            'launch/patient'
          ],
          'sub' => 'ae9ff5f4e4b741389904087d94cd19b2',
          'act' => {
            'icn' => '73806470379396828',
            'type' => 'patient',
            'vista_id' => '456|789012345^XX^456^XXXXX|X|789|012345678^XX^901^XXXXX|X|
                           234|567890^PN^234^XXXXX|X|567|890123456^XX^567^XXXXX|X|
                           890|12345^XX^890^XXXXX|X|111|111111111^XX^111^XXXXX|X'
          },
          'launch' => {
            'icn' => '73806470379396828',
            'sta3n' => '456'
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
  let(:json_ssoi_api_response) do
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
            'npi' => nil,
            'sec_id' => 'ae9ff5f4e4b741389904087d94cd19b2',
            'vista_id' => '',
            'type' => 'user'
          },
          'launch' => {}
        }
      }
    }
  end
  let(:auth_header) { { 'Authorization' => "Bearer #{token}" } }
  let(:static_auth_header) { { 'Authorization' => "Bearer #{static_token}" } }
  let(:opaque_auth_header) { { 'Authorization' => "Bearer #{opaque_token}" } }
  let(:invalid_auth_header) { { 'Authorization' => 'Bearer invalid-token' } }
  let(:user) { OpenidUser.new(build(:user_identity_attrs, :loa3)) }

  context 'with valid responses' do
    before do
      allow(JWT).to receive(:decode).and_return(jwt)
      Session.create(token:, uuid: user.uuid)
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

    it 'ssoi returns 200 and add the user to the session' do
      with_ssoi_profile_configured do
        post '/internal/auth/v2/validation', params: nil, headers: auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes'].keys).to \
          eq(json_ssoi_api_response['data']['attributes'].keys)
        expect(JSON.parse(response.body)['data']['attributes']['act'].keys).to \
          eq(json_ssoi_api_response['data']['attributes']['act'].keys)
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

  context 'when token request body is invalid' do
    let(:req_headers) do
      {
        'content-type' => 'application/json',
        'Authorization' => "Bearer #{opaque_token}",
        'apiKey' => 'saml-key'
      }
    end

    it 'v2 POST returns an unauthorized for a malformed request', :aggregate_failures do
      with_okta_okta_and_issued_url_configured do
        # bad json post
        post '/internal/auth/v2/validation', params: '{\'aud\': \'whatever\'}', headers: req_headers

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq '400'
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
      Session.create(uuid: user.uuid, token:)
      user.save
    end

    it 'v2 returns a server error if serialization fails', :aggregate_failures do
      allow_any_instance_of(OpenidAuth::ValidationSerializerV2).to receive(:attributes).and_raise(StandardError,
                                                                                                  'random')
      with_okta_configured do
        post '/internal/auth/v2/validation', params: nil, headers: auth_header

        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq '500'
      end
    end

    it 'v2 POST returns a not found when mpi profile returns not found', :aggregate_failures do
      allow_any_instance_of(OpenidUser).to receive(:mpi_status).and_return(:not_found)
      with_okta_configured do
        post '/internal/auth/v2/validation', params: nil, headers: auth_header

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq '404'
      end
    end

    it 'v2 POST returns a server error when mpi profile returns server error', :aggregate_failures do
      allow_any_instance_of(OpenidUser).to receive(:mpi_status).and_return(:server_error)
      with_okta_configured do
        post '/internal/auth/v2/validation', params: nil, headers: auth_header

        expect(response).to have_http_status(:bad_gateway)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq '502'
      end
    end
  end

  context 'with client credentials jwt' do
    before do
      allow(JWT).to receive(:decode).and_return(client_credentials_jwt)
    end

    it 'v2 POST returns true if the user is a veteran' do
      with_okta_configured do
        allow(RestClient).to receive(:get).and_return(launch_response)
        post '/internal/auth/v2/validation', params: nil, headers: auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes'].keys)
          .to eq(json_cc_api_response['data']['attributes'].keys)
        expect(JSON.parse(response.body)['data']['attributes']['launch']['patient']).to eq('73806470379396828')
      end
    end

    it 'v2 POST returns true if the user is a veteran using cache' do
      with_okta_configured do
        Session.create(token: hashed_token, launch: '73806470379396828')
        post '/internal/auth/v2/validation', params: nil, headers: auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes'].keys)
          .to eq(json_cc_api_response['data']['attributes'].keys)
        expect(JSON.parse(response.body)['data']['attributes']['launch']['patient']).to eq('73806470379396828')
      end
    end
  end

  context 'with client credentials jwt launch session' do
    before do
      allow(JWT).to receive(:decode).and_return(client_credentials_launch_jwt)
      Session.create(token: hashed_token, launch: '123V456')
    end

    it 'v2 POST returns true if the user is a veteran using cache' do
      with_okta_configured do
        post '/internal/auth/v2/validation', params: nil, headers: auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes'].keys)
          .to eq(json_cc_api_response['data']['attributes'].keys)
        expect(JSON.parse(response.body)['data']['attributes']['launch']['patient']).to eq('123V456')
      end
    end
  end

  context 'with client credentials jwt and failed launch lookup' do
    before do
      allow(JWT).to receive(:decode).and_return(client_credentials_jwt)
      allow(RestClient).to receive(:get).and_raise(failed_launch_response)
    end

    it 'v2 POST returns 401 Invalid launch context' do
      with_okta_configured do
        post '/internal/auth/v2/validation', params: nil, headers: auth_header
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq '401'
        expect(JSON.parse(response.body)['errors'].first['detail']).to eq 'Invalid launch context'
      end
    end
  end

  context 'with jwt requiring screening from charon' do
    before do
      allow(JWT).to receive(:decode).and_return(jwt_charon)
    end

    it 'v2 POST returns json response if valid user' do
      with_ssoi_charon_configured do
        VCR.use_cassette('charon/success') do
          allow(RestClient).to receive(:get).and_return(launch_with_sta3n_response)
          post '/internal/auth/v2/validation',
               params: { aud: %w[https://example.com/xxxxxxservices/xxxxx] },
               headers: auth_header
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes'].keys)
            .to eq(json_api_response_vista_id['data']['attributes'].keys)
          expect(JSON.parse(response.body)['data']['attributes']['launch']['sta3n']).to eq('456')
        end
        # Checks that the session was instantiated
        post '/internal/auth/v2/validation',
             params: { aud: %w[https://example.com/xxxxxxservices/xxxxx] },
             headers: auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes'].keys)
          .to eq(json_api_response_vista_id['data']['attributes'].keys)
        expect(JSON.parse(response.body)['data']['attributes']['launch']['sta3n']).to eq('456')
      end
    end

    it 'v2 POST returns json response if 400 charon response' do
      with_ssoi_charon_configured do
        VCR.use_cassette('charon/400') do
          stub_request(:get, 'http://example.com/smart/launch').to_return(
            body: { launch: 'eyAicGF0aWVudCI6ICIxMjM0NSIsICJzdGEzbiI6ICI0NTYiIH0K' }.to_json, status: 200
          )
          post '/internal/auth/v2/validation',
               params: { aud: %w[https://example.com/xxxxxxservices/xxxxx] },
               headers: auth_header
          expect(response).to have_http_status(:unauthorized)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail']).to eq 'Unknown vista site specified: [442]'
        end
        # Checks that the session was instantiated
        post '/internal/auth/v2/validation',
             params: { aud: %w[https://example.com/xxxxxxservices/xxxxx] },
             headers: auth_header
        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['errors'].first['detail']).to eq 'Unknown vista site specified: [442]'
      end
    end

    it 'v2 POST returns json response if 401 charon response' do
      with_ssoi_charon_configured do
        VCR.use_cassette('charon/401') do
          stub_request(:get, 'http://example.com/smart/launch').to_return(
            body: { launch: 'eyAicGF0aWVudCI6ICIxMjM0NSIsICJzdGEzbiI6ICI0NTYiIH0K' }.to_json, status: 200
          )
          post '/internal/auth/v2/validation',
               params: { aud: %w[https://example.com/xxxxxxservices/xxxxx] },
               headers: auth_header
          expect(response).to have_http_status(:unauthorized)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail']).to eq 'Charon menu-code: -1'
        end
      end
    end

    it 'v2 POST returns json response if 500 charon response' do
      with_ssoi_charon_configured do
        stub_request(:get, 'http://example.com/smart/launch').to_return(
          body: { launch: 'eyAicGF0aWVudCI6ICIxMjM0NSIsICJzdGEzbiI6ICI0NTYiIH0K' }.to_json, status: 200
        )

        post '/internal/auth/v2/validation',
             params: { aud: %w[https://example.com/xxxxxxservices/xxxxx] },
             headers: auth_header
        expect(response).to have_http_status(:internal_server_error)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['errors'].first['detail']).to eq 'Failed validation with Charon.'
      end
    end

    it 'v2 POST returns 401 response if invalid user' do
      with_ssoi_charon_configured do
        allow(RestClient).to receive(:get).and_return(launch_with_wrong_sta3n_response)
        post '/internal/auth/v2/validation',
             params: { aud: %w[https://example.com/xxxxxxservices/xxxxx] },
             headers: auth_header
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'v2 POST returns server error' do
      with_ssoi_charon_configured do
        allow(RestClient).to receive(:get).and_return(bad_launch_response)
        post '/internal/auth/v2/validation',
             params: { aud: %w[https://example.com/xxxxxxservices/xxxxx] },
             headers: auth_header
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  context 'with jwt requiring screening from charon in session' do
    let(:resp) { instance_double('Charon::Response', status: 200, body: {}) }
    let(:charon_response) { Charon::Response.new(resp) }

    before do
      allow(JWT).to receive(:decode).and_return(jwt_charon)
      Session.create(token:, uuid: user.uuid, charon_response:)
    end

    it 'v2 POST returns json response if valid user charon session' do
      with_ssoi_charon_configured do
        VCR.use_cassette('charon/success') do
          allow(RestClient).to receive(:get).and_return(launch_with_sta3n_response)

          post '/internal/auth/v2/validation',
               params: { aud: %w[https://example.com/xxxxxxservices/xxxxx] },
               headers: auth_header
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes'].keys)
            .to eq(json_api_response_vista_id['data']['attributes'].keys)
          expect(JSON.parse(response.body)['data']['attributes']['launch']['sta3n']).to eq('456')
        end
      end
    end
  end

  context 'static token from issued' do
    it 'static token from issued ok' do
      allow(RestClient).to receive(:get).and_return(issued_static_response)
      with_settings(
        Settings.oidc, issued_url: 'http://example.com/issued'
      ) do
        post '/internal/auth/v2/validation',
             params: { aud: %w[https://example.com/xxxxxxservices/xxxxx] },
             headers: static_auth_header
        expect(response).to have_http_status(:ok)
      end
    end

    it 'static token from issued aud mismatch' do
      allow(RestClient).to receive(:get).and_return(issued_static_response)
      with_settings(
        Settings.oidc, issued_url: 'http://example.com/issued'
      ) do
        post '/internal/auth/v2/validation',
             params: { aud: %w[https://example.com/xxxxxxservices/mismatch] },
             headers: static_auth_header
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq '401'
        expect(JSON.parse(response.body)['errors'].first['detail']).to eq 'Invalid audience'
      end
    end
  end

  context 'ssoi oauth opaque token' do
    it 'issued ok' do
      allow(RestClient).to receive(:get).and_return(issued_ssoi_response, openid_response)
      allow(RestClient).to receive(:post).and_return(ssoi_introspect_response)
      with_settings(Settings.oidc, issued_url: 'http://example.com/issued') do
        with_settings(Settings.oidc.opaque_clients.first, route: 'https://example.com', client_id: 123_456_789) do
          post '/internal/auth/v2/validation',
               params: { aud: %w[https://example.com/xxxxxxservices/xxxxx] },
               headers: opaque_auth_header
          expect(response).to have_http_status(:ok)
        end
      end
    end

    it 'issued aud mismatch' do
      allow(RestClient).to receive(:get).and_return(issued_ssoi_response)
      allow(RestClient).to receive(:post).and_return(ssoi_introspect_response)
      with_settings(Settings.oidc, issued_url: 'http://example.com/issued') do
        with_settings(Settings.oidc.opaque_clients.first, route: 'https://example.com', client_id: 123_456_789) do
          post '/internal/auth/v2/validation',
               params: { aud: %w[https://example.com/xxxxxxservices/mismatch] },
               headers: opaque_auth_header
          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)['errors'].first['code']).to eq '401'
          expect(JSON.parse(response.body)['errors'].first['detail']).to eq 'Invalid audience'
        end
      end
    end
  end
end
