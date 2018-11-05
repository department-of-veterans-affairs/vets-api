# frozen_string_literal: true

require 'rails_helper'

describe OpenidAuth::ValidationController, type: :controller do
  let(:token) do
    [{
      'ver' => 1,
      'jti' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
      'iss' => 'https://example.com/oauth2/default',
      'aud' => 'api://default',
      'iat' => Time.current.utc.to_i,
      'exp' => Time.current.utc.to_i + 3600,
      'cid' => '0oa1c01m77heEXUZt2p7',
      'uid' => '00u1zlqhuo3yLa2Xs2p7',
      'scp' => %w[profile email openid va_profile],
      'sub' => 'ae9ff5f4e4b741389904087d94cd19b2'
    }]
  end

  it 'should return 200 and add the user to the session' do
    allow(JWT).to receive(:decode).and_return(token)
    with_okta_configured do
      request.headers['Authorization'] = 'Bearer FakeToken'
      get :index
      expect(response).to be_ok
      expect(Session.find('FakeToken')).to_not be_nil
      expect(JSON.parse(response.body)['user']).to eq('vets.gov.user+20@gmail.com')
    end
  end
end
