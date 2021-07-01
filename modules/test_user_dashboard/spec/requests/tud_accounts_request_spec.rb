# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Test User Dashboard', type: :request do
  describe '#index' do
    context 'without any authentication headers' do
      it 'refuses the request' do
        get '/test_user_dashboard/tud_accounts'

        expect(response.status).to eq 403
        expect(response.content_type).to eq 'text/html'
      end
    end

    context 'with valid authentication headers' do
      it 'accepts the request and returns a response' do
        rsa_private = OpenSSL::PKey::RSA.new 2048
        rsa_public = rsa_private.public_key
        pub_key = Base64.encode64(rsa_public.to_der)
        token = JWT.encode 'test', rsa_private, 'RS256'

        get('/test_user_dashboard/tud_accounts',
            params: '',
            headers: {
              'JWT' => token,
              'PK' => pub_key
            })

        expect(response.status).to eq 200
        expect(response.content_type).to eq 'application/json; charset=utf-8'
      end
    end
  end
end
