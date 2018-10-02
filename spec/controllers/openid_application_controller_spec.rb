# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OpenidApplicationController, type: :controller do
  controller do
    def index
      render json: {
        'test' => 'It worked.',
        'user' => @current_user.email
      }
    end
  end

  let(:token) do
    [{
      'ver' => 1,
      'jti' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
      'iss' => 'https://deptva-vetsgov-eval.okta.com/oauth2/default',
      'aud' => 'api://default',
      'iat' => 1_538_509_491,
      'exp' => 1_538_513_091,
      'cid' => '0oa1c01m77heEXUZt2p7',
      'uid' => '00u1zlqhuo3yLa2Xs2p7',
      'scp' => %w[profile email openid va_profile],
      'sub' => 'ae9ff5f4e4b741389904087d94cd19b2'
    }, {
      'kid' => '1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU',
      'alg' => 'RS256'
    }]
  end

  describe '#authenticate' do
    context 'with no jwt supplied' do
      it 'should return 401' do
        get :index
        expect(response.status).to eq(401)
      end
    end

    context 'with a valid jwt supplied and no session' do
      before(:each) do
        allow(JWT).to receive(:decode).and_return(token)
      end

      it 'should return 200 and add the user to the session' do
        request.headers['Authorization'] = 'Bearer FakeToken'
        with_settings(
          Settings.oidc,
          auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/oauth-authorization-server',
          issuer: 'https://example.com/oauth2/default',
          profile_api_url: 'https://example.com/api/v1/users/',
          profile_api_token: 'token'
        ) do
          VCR.use_cassette('okta/metadata') do
            get :index
            expect(response).to be_ok
            expect(Session.find('FakeToken')).to_not be_nil
            expect(JSON.parse(response.body)['user']).to eq('vets.gov.user+20@gmail.com')
          end
        end
      end
    end
  end
end
