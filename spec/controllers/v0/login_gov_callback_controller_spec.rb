require 'rails_helper'
require 'sign_in/logingov/service'


RSpec.describe 'LoginGovCallbackController', type: :request do
  describe 'POST /v0/login_gov_callback/risc' do
    context 'when JWT is invalid' do
      it 'returns 401 for invalid JWT' do
        allow_any_instance_of(SignIn::Logingov::Service)
          .to receive(:jwt_decode)
          .and_raise(SignIn::Logingov::Errors::JWTDecodeError.new('Invalid token'))

        post '/v0/login_gov_callback/risc',
             params: 'not.a.real.jwt',
             headers: { 'CONTENT_TYPE' => 'application/jwt' }

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include('Not authorized')
        expect(response.body).to include('401')
      end
    end
  end
end