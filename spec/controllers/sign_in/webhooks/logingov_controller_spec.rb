# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/logingov/service'

RSpec.describe 'LoginGovController', type: :request do
  describe 'POST /sign_in/webhooks/logingov/risc' do
    context 'when JWT is invalid' do
      it 'returns 401 when jwt_decode raises JWTDecodeError' do
        allow_any_instance_of(SignIn::Logingov::Service)
          .to receive(:jwt_decode)
          .and_raise(SignIn::Logingov::Errors::JWTDecodeError.new('Invalid token'))

        post '/sign_in/webhooks/logingov/risc',
             params: 'not.a.real.jwt',
             headers: { 'CONTENT_TYPE' => 'application/jwt' }

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include('Invalid JWT')
      end
    end

    context 'when JWT decoding raises unexpected error' do
      it 'returns 500 when an unexpected error occurs' do
        allow_any_instance_of(SignIn::Logingov::Service)
          .to receive(:jwt_decode)
          .and_raise(StandardError.new('Something went wrong'))

        post '/sign_in/webhooks/logingov/risc',
             params: 'some.jwt.token',
             headers: { 'CONTENT_TYPE' => 'application/jwt' }

        expect(response).to have_http_status(:internal_server_error)
        expect(response.body).to include('Unexpected error')
      end
    end

    context 'when JWT is valid' do
      let(:valid_jwt) { 'valid.jwt.token' }

      it 'returns 202 Accepted for valid JWT' do
        allow_any_instance_of(SignIn::Logingov::Service)
          .to receive(:jwt_decode)
          .and_return({ 'sub' => 'valid-user' })

        post '/sign_in/webhooks/logingov/risc',
             params: valid_jwt,
             headers: { 'CONTENT_TYPE' => 'application/jwt' }

        expect(response).to have_http_status(:accepted)
        expect(response.body).to be_empty
      end

      it 'calls jwt_decode in the before_action with the correct JWT' do
        expect_any_instance_of(SignIn::Logingov::Service)
          .to receive(:jwt_decode)
          .with(valid_jwt)

        post '/sign_in/webhooks/logingov/risc',
             params: valid_jwt,
             headers: { 'CONTENT_TYPE' => 'application/jwt' }
      end
    end
  end
end
