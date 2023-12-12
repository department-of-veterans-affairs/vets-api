# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../rails_helper' # mock_ccg method
require 'claims_api/v2/error/lighthouse_error_handler'

describe ApplicationController, type: :controller do
  let(:scopes) { %w[system/claim.write] }

  controller do
    include ClaimsApi::V2::Error::LighthouseErrorHandler

    skip_before_action :authenticate

    def raise_unprocessable_entity
      raise ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity.new(detail: 'Test 422')
    end

    def raise_resource_not_found
      raise ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(detail: 'Test 404')
    end

    def raise_invalid_field_value
      raise ClaimsApi::Common::Exceptions::Lighthouse::InvalidFieldValue.new(detail: 'Test 400')
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
      get 'raise_invalid_field_value' => 'anonymous#raise_invalid_field_value'
      get 'raise_invalid_token' => 'anonymous#raise_invalid_token'
      get 'raise_expired_token_signature' => 'anonymous#raise_expired_token_signature'
    end
  end

  it 'returns a 422, Unprocessable entity, in line with LH standards' do
    mock_ccg(scopes) do |auth_header|
      # Following the normal headers: auth_header pattern fails due to
      # this rspec bug: https://github.com/rspec/rspec-rails/issues/1655
      # This is the recommended workaround from that issue thread.
      request.headers.merge!(auth_header)

      get :raise_unprocessable_entity

      expect(response).to have_http_status(:unprocessable_entity)

      parsed_body = JSON.parse(response.body)
      expect(parsed_body['errors'].size).to eq(1)
      expect(parsed_body['errors'][0]['title']).to eq('Unprocessable entity')
      expect(parsed_body['errors'][0]['detail']).to eq('Test 422')
      expect(parsed_body['errors'][0]['status']).to eq('422')
      expect(parsed_body['errors'][0]['status']).to be_a(String)
      expect(parsed_body['errors'][0]['source'].to_s).to include('{"pointer"=>')
    end
  end

  it 'returns a 404, Resource not found, in line with LH standards' do
    mock_ccg(scopes) do |auth_header|
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

  it 'returns a 400, Invalid field value, in line with LH standards' do
    mock_ccg(scopes) do |auth_header|
      request.headers.merge!(auth_header)

      get :raise_invalid_field_value

      expect(response).to have_http_status(:bad_request)

      parsed_body = JSON.parse(response.body)
      expect(parsed_body['errors'].size).to eq(1)
      expect(parsed_body['errors'][0]['title']).to eq('Invalid field value')
      expect(parsed_body['errors'][0]['detail']).to eq('Test 400')
      expect(parsed_body['errors'][0]['status']).to eq('400')
      expect(parsed_body['errors'][0]['status']).to be_a(String)
      expect(parsed_body['errors'][0]['source'].to_s).to include('{"pointer"=>')
    end
  end

  it 'catches an invalid token' do
    mock_ccg(scopes) do |auth_header|
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
