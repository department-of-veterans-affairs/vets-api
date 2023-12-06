# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../rails_helper' # mock_ccg method
require 'claims_api/v2/error/disability_compensation_error_handler'
require 'claims_api/v2/json_format_validation'

describe ApplicationController, type: :controller do
  let(:scopes) { %w[system/claim.write] }

  controller do
    include ClaimsApi::V2::Error::DisabilityCompensationErrorHandler
    include ClaimsApi::V2::JsonFormatValidation

    skip_before_action :authenticate

    def raise_unprocessable_entity
      raise Common::Exceptions::UnprocessableEntity.new(detail: 'Test 422')
    end

    def raise_resource_not_found
      raise Common::Exceptions::ResourceNotFound.new(detail: 'Test 404')
    end

    def raise_invalid_token
      raise Common::Exceptions::TokenValidationError.new(detail: 'Invalid token.')
    end

    def raise_expired_token_signature
      raise Common::Exceptions::TokenValidationError.new(detail: 'Signature has expired')
    end
  end

  before do
    routes.draw do
      get 'raise_unprocessable_entity' => 'anonymous#raise_unprocessable_entity'
      get 'raise_resource_not_found' => 'anonymous#raise_resource_not_found'
      get 'raise_invalid_token' => 'anonymous#raise_invalid_token'
      get 'raise_expired_token_signature' => 'anonymous#raise_expired_token_signature'
    end
  end

  it 'returns a 422 in line with LH standards' do
    mock_ccg(scopes) do |auth_header|
      # Following the normal headers: auth_header pattern fails due to
      # this rspec bug: https://github.com/rspec/rspec-rails/issues/1655
      # This is the recommended workaround from that issue thread.
      request.headers.merge!(auth_header)

      get :raise_unprocessable_entity

      expect(response).to have_http_status(:unprocessable_entity)

      parsed_body = JSON.parse(response.body)
      expect(parsed_body['errors'].size).to eq(1)
      expect(parsed_body['errors'][0]['title']).to eq('Unprocessable Entity')
      expect(parsed_body['errors'][0]['detail']).to eq('Test 422')
      expect(parsed_body['errors'][0]['status']).to eq('422')
      expect(parsed_body['errors'][0]['status']).to be_a(String)
      expect(parsed_body['errors'][0]['source'].to_s).to include('{"pointer"=>')
    end
  end

  it 'returns a 404 in line with LH standards' do
    mock_ccg(scopes) do |auth_header|
      # Following the normal headers: auth_header pattern fails due to
      # this rspec bug: https://github.com/rspec/rspec-rails/issues/1655
      # This is the recommended workaround from that issue thread.
      request.headers.merge!(auth_header)

      get :raise_resource_not_found

      expect(response).to have_http_status(:not_found)

      parsed_body = JSON.parse(response.body)
      expect(parsed_body['errors'].size).to eq(1)
      expect(parsed_body['errors'][0]['title']).to eq('Resource not found')
      expect(parsed_body['errors'][0]['detail']).to eq('Test 404')
      expect(parsed_body['errors'][0]['status']).to eq('404')
      expect(parsed_body['errors'][0]['status']).to be_a(String)
      expect(parsed_body['errors'][0]['source'].to_s).to include('{"pointer"=>')
    end
  end

  it 'catches an invalid token' do
    mock_ccg(scopes) do |auth_header|
      # Following the normal headers: auth_header pattern fails due to
      # this rspec bug: https://github.com/rspec/rspec-rails/issues/1655
      # This is the recommended workaround from that issue thread.
      request.headers.merge!(auth_header)

      get :raise_invalid_token

      expect(response).to have_http_status(:unauthorized)
      parsed_body = JSON.parse(response.body)
      expect(parsed_body['errors'].size).to eq(1)
      expect(parsed_body['errors'][0]['title']).to eq('Not authorized')
      expect(parsed_body['errors'][0]['detail']).to eq('Invalid token.')
      expect(parsed_body['errors'][0]['status']).to eq('401')
      expect(parsed_body['errors'][0]['status']).to be_a(String)
    end
  end

  it 'catches an expired token' do
    mock_ccg(scopes) do |auth_header|
      request.headers.merge!(auth_header)

      get :raise_expired_token_signature

      expect(response).to have_http_status(:unauthorized)
      parsed_body = JSON.parse(response.body)

      expect(parsed_body['errors'].size).to eq(1)
      expect(parsed_body['errors'][0]['title']).to eq('Not authorized')
      expect(parsed_body['errors'][0]['detail']).to eq('Signature has expired')
      expect(parsed_body['errors'][0]['status']).to eq('401')
      expect(parsed_body['errors'][0]['status']).to be_a(String)
    end
  end
end
