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
  let(:auth_header) { { 'Authorization' => "Bearer #{token}", 'Accept' => '*/*' } }
  let(:user) { create(:openid_user, identity_attrs: build(:user_identity_attrs, :loa3)) }

  before do
    allow(JWT).to receive(:decode).and_return(jwt)
    Session.create(uuid: user.uuid, token: token)
  end

  context 'with valid emis responses' do
    it 'returns the current users service history with one episode' do
      with_okta_configured do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
          get '/services/veteran_verification/v0/disability_rating', params: nil, headers: auth_header
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('disability_rating_response')
        end
      end
    end
  end

  context 'with request for a jws' do
    it 'returns a jwt with the claims in the payload' do
      with_okta_configured do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
          get '/services/veteran_verification/v0/disability_rating', params: nil, headers: {
            'Authorization' => "Bearer #{token}",
            'Accept' => 'application/jwt'
          }

          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)

          key_file = File.read("#{VeteranVerification::Engine.root}/spec/fixtures/verification_test.pem")
          rsa_public = OpenSSL::PKey::RSA.new(key_file)

          # JWT is mocked above because it is used by the implementation code.
          # Unfortunately, we also want to use the same module to verify the
          # response coming back in the tests, so we reset the mock here.
          # Otherwise, it just returns the fake JWT hash.
          RSpec::Mocks.space.proxy_for(JWT).reset

          claims = JWT.decode(response.body, rsa_public, true, algorithm: 'RS256').first

          expect(claims['data'].first['type']).to eq('disability_ratings')
        end
      end
    end
  end

  context 'with a 500 response' do
    it 'returns a bad gateway response' do
      with_okta_configured do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_500') do
          get '/services/veteran_verification/v0/disability_rating', params: nil, headers: auth_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end
  end

  context 'with a 403 unauthorized response' do
    it 'returns a not authorized response' do
      with_okta_configured do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_403') do
          get '/services/veteran_verification/v0/disability_rating', params: nil, headers: auth_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end
  end

  context 'with a generic 400 response' do
    it 'returns a bad request response' do
      with_okta_configured do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_400') do
          get '/services/veteran_verification/v0/disability_rating', params: nil, headers: auth_header
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end
  end
end
