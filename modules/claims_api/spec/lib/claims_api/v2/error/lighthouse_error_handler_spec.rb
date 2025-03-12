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
      error = { detail: 'Test 422' }

      raise ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity, error
    end

    def raise_bad_request
      error = [{ title: 'Test 400' }]

      raise ClaimsApi::Common::Exceptions::Lighthouse::BadRequest, error
    end

    def raise_resource_not_found
      raise ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(detail: 'Test 404')
    end

    def raise_json_526_validation_error
      errors_array =
        [
          { detail: 'invalid, account number is missing or blank', source: '/directDeposit/accountNumber',
            title: 'Unprocessable entity', status: '422' },
          { detail: 'invalid, routing number is missing or blank',
            source: '/directDeposit/routingNumber', title: 'Unprocessable entity', status: '422' }
        ]

      raise ClaimsApi::Common::Exceptions::Lighthouse::JsonFormValidationError, errors_array
    end

    def raise_invalid_token
      raise Common::Exceptions::TokenValidationError.new(detail: 'Invalid token.')
    end

    def raise_expired_token_signature
      raise Common::Exceptions::TokenValidationError.new(detail: 'Signature has expired')
    end

    def raise_timeout
      raise ClaimsApi::Common::Exceptions::Lighthouse::Timeout
    end

    def raise_bad_gateway
      raise ClaimsApi::Common::Exceptions::Lighthouse::BadGateway
    end
  end

  before do
    routes.draw do
      get 'raise_unprocessable_entity' => 'anonymous#raise_unprocessable_entity'
      get 'raise_bad_request' => 'anonymous#raise_bad_request'
      get 'raise_resource_not_found' => 'anonymous#raise_resource_not_found'
      get 'raise_json_526_validation_error' => 'anonymous#raise_json_526_validation_error'
      get 'raise_invalid_token' => 'anonymous#raise_invalid_token'
      get 'raise_expired_token_signature' => 'anonymous#raise_expired_token_signature'
      get 'raise_timeout' => 'anonymous#raise_timeout'
      get 'raise_bad_gateway' => 'anonymous#raise_bad_gateway'
    end
  end

  it 'returns a 422, Unprocessable entity, in line with LH standards for an array of errors' do
    mock_ccg(scopes) do |auth_header|
      # Following the normal headers: auth_header pattern fails due to
      # this rspec bug: https://github.com/rspec/rspec-rails/issues/1655
      # This is the recommended workaround from that issue thread.
      request.headers.merge!(auth_header)

      get :raise_json_526_validation_error

      expect(response).to have_http_status(:unprocessable_entity)

      parsed_body = JSON.parse(response.body)
      expect(parsed_body['errors'].size).to eq(2)
      expect(parsed_body['errors'][0]['title']).to eq('Unprocessable entity')
      expect(parsed_body['errors'][0]['detail']).to eq('invalid, account number is missing or blank')
      expect(parsed_body['errors'][0]['status']).to eq('422')
      expect(parsed_body['errors'][0]['status']).to be_a(String)
      expect(parsed_body['errors'][0]['source'].to_s).to include('{"pointer"=>')
    end
  end

  it 'returns a 400, Bad Request, in line with LH standards for an array of errors' do
    mock_ccg(scopes) do |auth_header|
      request.headers.merge!(auth_header)

      get :raise_bad_request

      expect(response).to have_http_status(:bad_request)

      parsed_body = JSON.parse(response.body)
      expect(parsed_body['errors'].size).to eq(1)
      expect(parsed_body['errors'][0]['title']).to eq('Test 400')
      expect(parsed_body['errors'][0]['detail']).to be_nil
      expect(parsed_body['errors'][0]['status']).to eq('400')
      expect(parsed_body['errors'][0]['status']).to be_a(String)
      expect(parsed_body['errors'][0]['source'].to_s).not_to include('{"pointer"=>')
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
      expect(parsed_body['errors'][0]['source'].to_s).not_to include('{"pointer"=>')
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

  it 'catches a timeout' do
    mock_ccg(scopes) do |auth_header|
      request.headers.merge!(auth_header)

      get :raise_timeout

      expect(response).to have_http_status(:gateway_timeout)
      parsed_body = JSON.parse(response.body)
      expect(parsed_body['errors'][0]['title']).to eq('Upstream timeout')
      expect(parsed_body['errors'][0]['detail']).to eq('An upstream service timed out.')
      expect(parsed_body['errors'][0]['status']).to eq('504')
      expect(parsed_body['errors'][0]['status']).to be_a(String)
    end
  end

  it 'catches an external timeout and returns bad gateway' do
    mock_ccg(scopes) do |auth_header|
      request.headers.merge!(auth_header)

      get :raise_bad_gateway

      expect(response).to have_http_status(:bad_gateway)
      parsed_body = JSON.parse(response.body)
      expect(parsed_body['errors'][0]['title']).to eq('Bad gateway')
      expect(parsed_body['errors'][0]['detail']).to eq(
        'The server received an invalid or null response from an upstream server.'
      )
      expect(parsed_body['errors'][0]['status']).to eq('502')
      expect(parsed_body['errors'][0]['status']).to be_a(String)
    end
  end
end
