# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PPIU', type: :request do
  include SchemaMatchers

  let(:user) { build(:user, :loa3) }
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'GET /v0/ppiu' do
    context 'with a valid evss response' do
      it 'should match the ppiu schema' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          get '/v0/ppiu', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('payment_information')
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a not authorized response' do
        VCR.use_cassette('evss/ppiu/forbidden') do
          get '/v0/ppiu', nil, auth_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('payment_information_errors', strict: false)
        end
      end
    end

    context 'with a 500 server error type' do
      it 'should return a service error response' do
        VCR.use_cassette('evss/ppiu/service_error') do
          get '/v0/ppiu', nil, auth_header
          expect(response).to have_http_status(:service_unavailable)
          expect(response).to match_response_schema('payment_information_errors')
        end
      end
    end
  end
end
