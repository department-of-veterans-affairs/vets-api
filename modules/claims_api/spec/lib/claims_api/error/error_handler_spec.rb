# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/special_issue_mappers/bgs'
require 'token_validation/v2/client'
require 'claims_api/error/error_handler'

describe ApplicationController, type: :controller do
  let(:scopes) { %w[system/claim.write] }

  controller do
    include ClaimsApi::Error::ErrorHandler
    skip_before_action :authenticate

    def raise_invalid_token
      raise Common::Exceptions::TokenValidationError.new(detail: 'Invalid token.')
    end

    def raise_expired_token_signature
      raise Common::Exceptions::TokenValidationError.new(detail: 'JWT::ExpiredSignature')
    end
  end

  before do
    routes.draw do
      get 'raise_invalid_token' => 'anonymous#raise_invalid_token'
      get 'raise_expired_token_signature' => 'anonymous#raise_expired_token_signature'
    end
  end

  it 'catches an invalid token' do
    with_okta_user(scopes) do |auth_header|
      # Following the normal headers: auth_header pattern fails due to
      # this rspec bug: https://github.com/rspec/rspec-rails/issues/1655
      # This is the recommended workaround from that issue thread.
      request.headers.merge!(auth_header)

      get :raise_invalid_token

      expect(response).to have_http_status(:unauthorized)
      parsed_body = JSON.parse(response.body)
      expect(parsed_body['errors'].size).to eq(1)
      expect(parsed_body['errors'][0]['title']).to eq('Not authorized')
      expect(parsed_body['errors'][0]['detail']).to eq('Not authorized.')
    end
  end

  it 'catches an expired token' do
    with_okta_user(scopes) do |auth_header|
      request.headers.merge!(auth_header)

      get :raise_expired_token_signature

      expect(response).to have_http_status(:unauthorized)
      parsed_body = JSON.parse(response.body)

      expect(parsed_body['errors'].size).to eq(1)
      expect(parsed_body['errors'][0]['title']).to eq('Not authorized')
      expect(parsed_body['errors'][0]['detail']).to eq('Not authorized.')
    end
  end
end
